-- حروف — ترقية سكيما التحدي اليومي (نتيجة/تصنيف/إعادة محاولة)
-- شغّل هذا الملف بعد schema.sql وschema_social.sql معا في SQL Editor
-- لمشروعك (يحتاج جدول public.friendships من schema_social.sql لتصنيف
-- الأصدقاء). كل تعديل هنا إضافي أو إعادة تسمية فقط — لا حذف بيانات:
-- الأعمدة الجديدة nullable/بقيمة افتراضية، والجداول تُعاد تسميتها لا
-- تُنشأ من الصفر، فتبقى كل السجلات القديمة سليمة.

-- ─────────────────────── daily_challenges: أعمدة أكثر تركيبا ───────────────────────

alter table public.daily_challenges rename column challenge_date to date;
alter table public.daily_challenges rename column puzzle_data to puzzle_json;

alter table public.daily_challenges add column if not exists seed text;
alter table public.daily_challenges add column if not exists letter_rack jsonb;
alter table public.daily_challenges add column if not exists core_words jsonb;
alter table public.daily_challenges add column if not exists bonus_words jsonb;
alter table public.daily_challenges add column if not exists difficulty text;

-- ─────────────────────── daily_attempts → daily_challenge_results ───────────────────────
-- إعادة تسمية جدول (لا إنشاء جديد) تُبقي RLS/UNIQUE/التريغر الحالية
-- سليمة تلقائيا في Postgres (مرتبطة بمعرّف الجدول الداخلي لا باسمه)

alter table public.daily_attempts rename to daily_challenge_results;
-- سياسة INSERT المباشر من v1 تنجو من إعادة التسمية، وتناقض ما أدناه:
-- الإرسال كله عبر submit_daily_challenge_result (SECURITY DEFINER)،
-- وبقاؤها يتيح للعميل إدراج أي score مباشرة في الجدول
drop policy if exists "daily_attempts owner insert" on public.daily_challenge_results;
alter table public.daily_challenge_results rename column challenge_date to date;
alter table public.daily_challenge_results rename column created_at to submitted_at;

alter table public.daily_challenge_results
  add column if not exists score int not null default 0;
alter table public.daily_challenge_results
  add column if not exists time_ms int not null default 0;
alter table public.daily_challenge_results
  add column if not exists words_found int not null default 0;
alter table public.daily_challenge_results
  add column if not exists hints_used int not null default 0;

-- العمود القديم result (JSONB: قائمة حالة كل كلمة) يبقى للقراءة التاريخية
-- فقط — لا الكتابة الجديدة (submit_daily_challenge_result أدناه) تملؤه
alter table public.daily_challenge_results alter column result drop not null;

-- ─────────────────────── تحديث دالة الستريك لاسم العمود الجديد ───────────────────────
-- المنطق نفسه بالضبط، فقط new.challenge_date → new.date بعد إعادة التسمية

create or replace function public.handle_daily_attempt()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  prev date;
begin
  select last_played_date into prev from public.streaks where user_id = new.user_id;

  if prev is null then
    insert into public.streaks (user_id, current_streak, best_streak, last_played_date)
    values (new.user_id, 1, 1, new.date);
  elsif prev = new.date - 1 then
    update public.streaks
      set current_streak = current_streak + 1,
          best_streak = greatest(best_streak, current_streak + 1),
          last_played_date = new.date
      where user_id = new.user_id;
  elsif prev = new.date then
    null;
  else
    update public.streaks
      set current_streak = 1,
          best_streak = greatest(best_streak, 1),
          last_played_date = new.date
      where user_id = new.user_id;
  end if;

  return new;
end;
$$;

-- ─────────────────────── تحديث get_or_create_daily_challenge ───────────────────────
-- نفس منطق الاختيار الحتمي القديم بالضبط، فقط بأسماء الأعمدة الجديدة،
-- مع تعبئة الأعمدة المركّبة الجديدة من puzzle_json (letters/words/bonus_words)
-- إن وُجدت فيه — بيانات المخزون القديمة لن تملأ seed/difficulty (لا قيمة
-- مصدر لهما)، فتبقيان null لصفوف قديمة، وهذا متوقَّع وغير ضار

create or replace function public.get_or_create_daily_challenge()
returns public.daily_challenges
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := (now() at time zone 'utc')::date;
  existing public.daily_challenges;
  pool_count int;
  pick int;
  chosen jsonb;
begin
  select * into existing from public.daily_challenges where date = today;
  if found then
    return existing;
  end if;

  select count(*) into pool_count from public.daily_puzzle_pool;
  if pool_count = 0 then
    raise exception 'daily_puzzle_pool is empty — run tool/daily_pool_seed.sql first';
  end if;

  pick := (('x' || substr(md5(today::text), 1, 8))::bit(32)::int % pool_count);
  if pick < 0 then pick := pick + pool_count; end if;

  select puzzle_data into chosen from public.daily_puzzle_pool offset pick limit 1;

  insert into public.daily_challenges (
    date, puzzle_json, letter_rack, bonus_words
  )
  values (
    today, chosen, chosen -> 'letters', chosen -> 'bonus_words'
  )
  on conflict (date) do nothing
  returning * into existing;

  if existing.date is null then
    select * into existing from public.daily_challenges where date = today;
  end if;

  return existing;
end;
$$;

-- ─────────────────────── إرسال نتيجة (يستبدل daily_attempts.insert المباشر) ───────────────────────
-- SECURITY DEFINER بدل سماح INSERT/UPDATE مباشر للعميل: القرار "إعادة
-- المحاولة تستبدل فقط إن كانت أعلى" يُطبَّق هنا حصرا، لا يمكن للعميل
-- تجاوزه بإرسال UPDATE مباشر لأن لا سياسة RLS تسمح بذلك أصلا

-- p_result_detail: نفس شكل JSON القديم {"words":[...], "attempts": n} —
-- يُحفَظ في العمود result القديم فقط لعرض شبكة نتائج الكلمات (_ResultGrid
-- في daily_challenge_screen.dart)، لا يُستخدَم في حساب النتيجة/التصنيف
create or replace function public.submit_daily_challenge_result(
  p_date date,
  p_score int,
  p_time_ms int,
  p_words_found int,
  p_hints_used int,
  p_result_detail jsonb
)
returns public.daily_challenge_results
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  rec public.daily_challenge_results;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  select * into rec from public.daily_challenge_results
    where user_id = me and date = p_date;

  if not found then
    insert into public.daily_challenge_results
      (user_id, date, score, time_ms, words_found, hints_used, result)
    values (me, p_date, p_score, p_time_ms, p_words_found, p_hints_used, p_result_detail)
    returning * into rec;
    return rec;
  end if;

  if p_score > rec.score then
    update public.daily_challenge_results
      set score = p_score, time_ms = p_time_ms,
          words_found = p_words_found, hints_used = p_hints_used,
          result = p_result_detail, submitted_at = now()
      where user_id = me and date = p_date
      returning * into rec;
  end if;

  return rec;
end;
$$;

grant execute on function public.submit_daily_challenge_result(date, int, int, int, int, jsonb)
  to anon, authenticated;

-- ─────────────────────── تصنيف اليوم (عالمي) ───────────────────────

create or replace function public.daily_challenge_today_rank(p_date date)
returns table (my_rank bigint, total_players bigint)
language sql
security definer
set search_path = public
as $$
  with ranked as (
    select user_id, rank() over (order by score desc) as r
    from public.daily_challenge_results
    where date = p_date
  )
  select
    (select r from ranked where user_id = auth.uid()),
    (select count(*) from public.daily_challenge_results where date = p_date);
$$;

grant execute on function public.daily_challenge_today_rank(date) to anon, authenticated;

-- ─────────────────────── تصنيف اليوم (الأصدقاء) ───────────────────────
-- نفس نمط دائرة "أنا + كل صداقة مقبولة" في friends_leaderboard تماما
-- (schema_social.sql) — يحتاج هذا الملف أن يُشغَّل بعد ذاك

create or replace function public.daily_challenge_friends_rank(p_date date)
returns table (my_rank bigint, total_friends bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    return;
  end if;

  return query
  with circle as (
    select me as uid
    union
    select case when f.user_id = me then f.friend_id else f.user_id end
    from public.friendships f
    where f.status = 'accepted' and (f.user_id = me or f.friend_id = me)
  ),
  scored as (
    select c.uid, coalesce(r.score, 0) as score
    from circle c
    left join public.daily_challenge_results r
      on r.user_id = c.uid and r.date = p_date
  ),
  ranked as (
    select uid, rank() over (order by score desc) as r from scored
  )
  select
    (select r from ranked where uid = me),
    (select count(*) from circle);
end;
$$;

grant execute on function public.daily_challenge_friends_rank(date) to anon, authenticated;

-- ─────────────────────── إصلاح توافق: اللوحتان القديمتان كانتا تشيران ───────────────────────
-- ─────────────────────── إلى public.daily_attempts/challenge_date مباشرة ───────────────────────
-- friends_leaderboard (schema_social.sql) وglobal_leaderboard
-- (schema_rewards.sql) كلاهما يستعلم مقياس 'weekly' من الجدول القديم
-- بالاسم مباشرة — بعد إعادة التسمية أعلاه سينكسران فعليا (علاقة غير
-- موجودة) ما لم يُعاد تعريفهما هنا بالاسم الجديد. أيضا فرصة لاستبدال
-- تفكيك JSONB الهش (jsonb_array_elements(result -> 'words')) بالعمود
-- المركّب الجديد words_found المضمون التعبئة دوما، بدل الاعتماد على
-- عمود result الاختياري الآن — المنطق نفسه غير ذلك بالضبط، لا تغيير في
-- السلوك عدا هذا.

create or replace function public.friends_leaderboard(metric text default 'streak')
returns table (
  player_id uuid,
  display_name text,
  friend_code text,
  metric_value int,
  place bigint,
  is_me boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    return;
  end if;

  return query
  with circle as (
    select me as uid
    union
    select case when f.user_id = me then f.friend_id else f.user_id end
    from public.friendships f
    where f.status = 'accepted' and (f.user_id = me or f.friend_id = me)
  ),
  scored as (
    select
      c.uid as uid,
      coalesce(p.display_name, 'لاعب') as dname,
      coalesce(p.friend_code, '------') as fcode,
      case metric
        when 'streak' then coalesce(s.current_streak, 0)
        when 'weekly' then coalesce((
          select sum(a.words_found)
          from public.daily_challenge_results a
          where a.user_id = c.uid
            and a.date >= date_trunc('week', (now() at time zone 'utc'))::date
        ), 0)::int
        else coalesce(p.total_score, 0)
      end as val
    from circle c
    left join public.profiles p on p.user_id = c.uid
    left join public.streaks s on s.user_id = c.uid
  )
  select
    scored.uid,
    scored.dname,
    scored.fcode,
    scored.val,
    rank() over (order by scored.val desc),
    scored.uid = me
  from scored
  order by scored.val desc, scored.dname;
end;
$$;

grant execute on function public.friends_leaderboard(text) to anon, authenticated;

create or replace function public.global_leaderboard(
  metric text default 'score',
  max_rows int default 50
)
returns table (
  player_id uuid,
  display_name text,
  friend_code text,
  metric_value int,
  place bigint,
  is_me boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  capped int := least(greatest(coalesce(max_rows, 50), 1), 200);
begin
  return query
  with scored as (
    select
      p.user_id as uid,
      coalesce(p.display_name, 'لاعب') as dname,
      case metric
        when 'streak' then coalesce(s.current_streak, 0)
        when 'weekly' then coalesce((
          select sum(a.words_found)
          from public.daily_challenge_results a
          where a.user_id = p.user_id
            and a.date >= date_trunc('week', (now() at time zone 'utc'))::date
        ), 0)::int
        else coalesce(p.total_score, 0)
      end as val
    from public.profiles p
    left join public.streaks s on s.user_id = p.user_id
  ),
  ranked as (
    select scored.*, rank() over (order by scored.val desc, scored.dname) as rnk
    from scored
  )
  select r.uid, r.dname,
         case when r.uid = me
              then coalesce((select pr.friend_code from public.profiles pr
                             where pr.user_id = me), '------')
              else '------' end,
         r.val, r.rnk, r.uid = me
  from ranked r
  where r.rnk <= capped or r.uid = me
  order by r.rnk;
end;
$$;

grant execute on function public.global_leaderboard(text, int) to anon, authenticated;

-- ─────────────────────── تصنيف الأسبوع (عالمي) ───────────────────────
-- النطاق الثالث للتحدي اليومي: مجموع نتائج اللاعب هذا الأسبوع مقابل
-- الجميع. يستخدم نفس تعبير حدود الأسبوع المستخدم في مقياس 'weekly'
-- أعلاه بالضبط (اثنين 00:00 UTC) كي لا تنشأ حدود أسبوع ثانية مختلفة.
-- شكل الإرجاع مطابق لـdaily_challenge_today_rank كي يبقى تحليل العميل
-- موحّدا لكل النطاقات الثلاثة.

create or replace function public.daily_challenge_week_rank()
returns table (my_rank bigint, total_players bigint)
language sql
security definer
set search_path = public
as $$
  with weekly as (
    select user_id, sum(score) as total
      from public.daily_challenge_results
      where date >= date_trunc('week', (now() at time zone 'utc'))::date
      group by user_id
  ),
  ranked as (
    select user_id, rank() over (order by total desc) as r from weekly
  )
  select
    (select r from ranked where user_id = auth.uid()),
    (select count(*) from weekly);
$$;

grant execute on function public.daily_challenge_week_rank() to anon, authenticated;
