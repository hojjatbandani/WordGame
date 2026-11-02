-- حروف — سكيما الأصدقاء والدعوات (v2)
--
-- شغّل هذا الملف *بعد* كل الملفات السابقة في SQL Editor:
--   schema.sql → schema_social.sql → schema_rewards.sql →
--   schema_daily_challenge_v2.sql → schema_leagues.sql →
--   schema_duels.sql → schema_progression.sql → (هذا الملف)
--
-- يعيد تعريف كل دالة تلمس friendships لأن الجدول نفسه تغيّر شكله هنا،
-- فآخر تعريف هو الساري. ما يغيّره هذا الملف عن v1:
--
--  1) friendships صارت (user_a, user_b) بزوج مرتّب وفريد بدل
--     (user_id, friend_id) — صداقة واحدة بين شخصين مهما كان اتجاه
--     الطلب، فيستحيل وجود صفّين متعاكسين لنفس الثنائي. اتجاه الطلب
--     محفوظ في requested_by (لازم: الزوج المرتّب يمحو "من طلب من").
--  2) سقف 200 صديق، مفروض في الخادم لا في الواجهة.
--  3) رفض الطلب (لم يكن موجودا أصلا: كان القبول فقط).
--  4) رمز الصديق ثمانية محارف بدل ستة.
--  5) الدعوة صارت على مرحلتين: المدعوّ يأخذ مئة فورا، والداعي لا يُدفع
--     له إلا حين يبلغ المدعوّ المستوى الثالث فعلا — والقرار يُتخذ هنا
--     في الخادم من lifetime_xp المخزَّنة (تصاعدية فقط عبر sync_my_xp)،
--     لا من طلب يرسله الداعي. هذا هو الحاجز الفعلي ضد مزارع الحسابات:
--     إنشاء حساب واستبدال رمز صار بلا مقابل للداعي.
--  6) سقف 20 دعوة مدفوعة لكل حساب + استبدال واحد لكل تثبيت.
--  7) مكافآت مراحل عند 3 و5 و10 دعوات ناجحة — زخرفية فقط، لا عملات.

-- ─────────────────────── ثوابت التوازن ───────────────────────
-- دوال لا جداول: تُقرأ من كل الدوال أدناه فيبقى الرقم في مكان واحد،
-- ويطابق lib/config/balance_config.dart حرفا بحرف.

create or replace function public.max_friends() returns int
  language sql immutable as $$ select 200 $$;

create or replace function public.referral_max_paid_per_account() returns int
  language sql immutable as $$ select 20 $$;

-- المستوى الذي يجب أن يبلغه المدعوّ قبل أن يُدفع للداعي
create or replace function public.referral_qualify_level() returns int
  language sql immutable as $$ select 3 $$;

-- ─────────────────────── مستوى اللاعب من XP ───────────────────────
-- مرآة حرفية لـ lib/data/progression/player_level_curve.dart:
--   تكلفة الانتقال من n إلى n+1 = xpBaseForLevel + xpIncrementPerLevel*(n-1)
--   = 150 + 50*(n-1)
-- فمجموع ما يلزم للوصول إلى المستوى L هو مجموع حسابي:
--   S(L) = sum(n=1..L-1) [150 + 50*(n-1)] = 125*(L-1) + 25*(L-1)^2
-- وحلّ S(L) <= xp بالنسبة إلى L يعطي الصيغة المغلقة أدناه. تُبقى
-- immutable كي تصلح داخل الفهارس والأعمدة المولَّدة لاحقا إن لزم.
--
-- سبب الاشتقاق في الخادم بدل قبول مستوى يرسله العميل: مؤهِّل الدعوة
-- يجب أن يُحسب من رقم واحد تصاعدي فقط (lifetime_xp) لا من ادّعاء.
create or replace function public.player_level_from_xp(xp int)
returns int
language sql
immutable
as $$
  select greatest(1, floor((-125 + sqrt(15625.0 + 100.0 * greatest(coalesce(xp, 0), 0))) / 50.0)::int + 1);
$$;

-- ─────────────────────── ملف اللاعب: صورة رمزية ───────────────────────

alter table public.profiles
  add column if not exists avatar_id text not null default 'a1';

-- XP التراكمية (تصاعدية فقط عبر sync_my_xp). كانت تُقرأ في my_friends
-- وmy_pending_requests وtry_qualify_referral وsync_my_xp أدناه بلا أن
-- ينشئها أي ملف، فيفشل تطبيق هذا الملف عند أول دالة sql تلمسها.
alter table public.profiles
  add column if not exists lifetime_xp int not null default 0;

-- كل كتابة إلى profiles تمرّ بدوال SECURITY DEFINER (set_my_display_name،
-- sync_my_xp، redeem_referral..). سماح UPDATE مباشر للعميل كان يتيح له
-- ضبط total_score وfriend_code وlifetime_xp بنفسه — فيسقط حاجز «المستوى
-- الثالث» ضد مزارع الدعوات، وحدّ العشرين محرفا في الاسم.
drop policy if exists "profiles owner update" on public.profiles;

-- رمز صديق من ثمانية محارف. نفس الأبجدية الخالية من الملتبس (لا 0/O ولا
-- 1/I) كي يبقى قابلا للإملاء صوتيا في مكالمة.
create or replace function public.generate_friend_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
  i int;
begin
  loop
    code := '';
    for i in 1..8 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.profiles where friend_code = code);
  end loop;
  return code;
end;
$$;

-- ترقية الرموز القديمة (ستة محارف) إلى ثمانية *بإلحاق* محرفين لا
-- بتوليد رمز جديد: الرمز دائم، ومن حفظ رمزه القديم يبقى مقدّمة رمزه
-- الجديد. الفرادة محفوظة تلقائيا لأن المقدّمة كانت فريدة أصلا.
do $$
declare
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  r record;
  suffix text;
  i int;
begin
  for r in select user_id, friend_code from public.profiles where length(friend_code) < 8 loop
    suffix := '';
    for i in 1..(8 - length(r.friend_code)) loop
      suffix := suffix || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    update public.profiles set friend_code = r.friend_code || suffix
      where user_id = r.user_id;
  end loop;
end;
$$;

-- ─────────────────────── الصداقات (زوج مرتّب) ───────────────────────
-- الهجرة: نحتفظ بنسخة من الجدول القديم قبل إسقاطه (لا نثق بأن لا أحد
-- سيحتاجها)، ثم نبني الجدول الجديد وننقل إليه الصفوف بزوج مرتّب.
-- drop ... cascade يُسقط سياسات RLS القديمة فقط؛ الدوال في Postgres لا
-- تُسجَّل كتابعة لجدول فلا تتأثر، وكلها مُعاد تعريفها أدناه على أي حال.

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'friendships'
      and column_name = 'user_id'
  ) then
    create table if not exists public.friendships_v1_backup as
      select * from public.friendships;
    drop table public.friendships cascade;
  end if;
end;
$$;

create table if not exists public.friendships (
  id bigint generated always as identity primary key,
  user_a uuid not null references auth.users (id) on delete cascade,
  user_b uuid not null references auth.users (id) on delete cascade,
  -- من أرسل الطلب. الزوج المرتّب يمحو الاتجاه، وبلا هذا العمود يستحيل
  -- معرفة أيّ الطرفين يملك القبول أو الرفض.
  requested_by uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  constraint friendships_sorted_pair check (user_a < user_b),
  constraint friendships_unique_pair unique (user_a, user_b)
);

create index if not exists friendships_user_a_idx on public.friendships (user_a);
create index if not exists friendships_user_b_idx on public.friendships (user_b);

do $$
begin
  if to_regclass('public.friendships_v1_backup') is not null then
    insert into public.friendships (user_a, user_b, requested_by, status, created_at, accepted_at)
    select
      least(user_id, friend_id),
      greatest(user_id, friend_id),
      user_id,
      status,
      created_at,
      case when status = 'accepted' then created_at end
    from public.friendships_v1_backup
    -- عند وجود صفّين متعاكسين للثنائي نفسه في البيانات القديمة، الأقدم
    -- يفوز و«مقبول» يغلب «معلّق»
    order by (status = 'accepted') desc, created_at asc
    on conflict on constraint friendships_unique_pair do nothing;
  end if;
end;
$$;

alter table public.friendships enable row level security;

drop policy if exists "friendships visible to both sides" on public.friendships;
create policy "friendships visible to both sides"
  on public.friendships for select
  using (auth.uid() = user_a or auth.uid() = user_b);

-- لا سياسة insert/update/delete مباشرة: كل تعديل يمر بدوال أدناه كي
-- يبقى سقف المئتين والزوج المرتّب مضمونين في مكان واحد

-- عدد أصدقائي المقبولين
create or replace function public.my_friend_count()
returns int
language sql
security definer
set search_path = public
as $$
  select count(*)::int from public.friendships
    where status = 'accepted'
      and (user_a = auth.uid() or user_b = auth.uid());
$$;

grant execute on function public.my_friend_count() to anon, authenticated;

create or replace function public.friend_count_of(target uuid)
returns int
language sql
security definer
set search_path = public
as $$
  select count(*)::int from public.friendships
    where status = 'accepted' and (user_a = target or user_b = target);
$$;

-- إضافة صديق برمزه. SECURITY DEFINER كي لا نفتح قراءة كل الملفات للبحث
-- عن الرمز (منعا لتعداد المستخدمين).
create or replace function public.add_friend_by_code(code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  target uuid;
  a uuid;
  b uuid;
  existing public.friendships;
begin
  if me is null then
    return 'not_authenticated';
  end if;

  select user_id into target from public.profiles
    where friend_code = upper(btrim(code));
  if target is null then
    return 'not_found';
  end if;
  if target = me then
    return 'self';
  end if;

  -- السقف يُفحص للطرفين: قائمة ممتلئة عند الطرف الآخر تعني أن الطلب لن
  -- يُقبل أبدا، فرفضه الآن أصدق من تركه معلّقا إلى الأبد
  if public.my_friend_count() >= public.max_friends() then
    return 'full';
  end if;
  if public.friend_count_of(target) >= public.max_friends() then
    return 'target_full';
  end if;

  a := least(me, target);
  b := greatest(me, target);

  select * into existing from public.friendships
    where user_a = a and user_b = b;

  if found then
    if existing.status = 'accepted' then
      return 'exists';
    end if;
    -- طلب معلّق قادم من الطرف الآخر: إدخال رمزه الآن = قبول له
    if existing.requested_by <> me then
      update public.friendships
        set status = 'accepted', accepted_at = now()
        where id = existing.id;
      return 'accepted';
    end if;
    return 'pending'; -- طلبي أنا، ما زال ينتظره
  end if;

  insert into public.friendships (user_a, user_b, requested_by)
    values (a, b, me);
  return 'sent';
end;
$$;

grant execute on function public.add_friend_by_code(text) to anon, authenticated;

-- الطلبات الواردة المعلّقة: ما طلبه غيري ولم أقبله بعد
create or replace function public.my_pending_requests()
returns table (
  friendship_id bigint,
  from_id uuid,
  from_name text,
  from_code text,
  from_avatar text,
  from_level int,
  requested_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    f.id,
    f.requested_by,
    coalesce(p.display_name, 'لاعب'),
    coalesce(p.friend_code, '--------'),
    coalesce(p.avatar_id, 'a1'),
    public.player_level_from_xp(coalesce(p.lifetime_xp, 0)),
    f.created_at
  from public.friendships f
  left join public.profiles p on p.user_id = f.requested_by
  where f.status = 'pending'
    and f.requested_by <> auth.uid()
    and (f.user_a = auth.uid() or f.user_b = auth.uid())
  order by f.created_at desc;
$$;

grant execute on function public.my_pending_requests() to anon, authenticated;

-- القبول: المستقبِل فقط، ومع فحص السقف مرة أخرى لحظة القبول (القائمة قد
-- تكون امتلأت بين إرسال الطلب وقبوله)
create or replace function public.accept_friend_request(request_id bigint)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  rec public.friendships;
begin
  if me is null then
    return 'not_authenticated';
  end if;

  select * into rec from public.friendships
    where id = request_id and status = 'pending'
      and requested_by <> me and (user_a = me or user_b = me);
  if not found then
    return 'not_found';
  end if;

  if public.my_friend_count() >= public.max_friends() then
    return 'full';
  end if;
  if public.friend_count_of(rec.requested_by) >= public.max_friends() then
    return 'target_full';
  end if;

  update public.friendships
    set status = 'accepted', accepted_at = now()
    where id = rec.id;
  return 'accepted';
end;
$$;

grant execute on function public.accept_friend_request(bigint) to anon, authenticated;

-- الرفض يحذف الصفّ لا يعلّمه: الحذف يترك للطرف الآخر أن يحاول ثانية
-- لاحقا، بينما حالة "مرفوض" دائمة كانت ستحبس الثنائي إلى الأبد بسبب
-- ضغطة واحدة. ولا نُعلم الرافض عنه شيئا — لا إشعار رفض إطلاقا.
create or replace function public.decline_friend_request(request_id bigint)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    return 'not_authenticated';
  end if;

  delete from public.friendships
    where id = request_id and status = 'pending'
      and requested_by <> me and (user_a = me or user_b = me);

  if not found then
    return 'not_found';
  end if;
  return 'declined';
end;
$$;

grant execute on function public.decline_friend_request(bigint) to anon, authenticated;

create or replace function public.remove_friend(friend uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    return 'not_authenticated';
  end if;
  delete from public.friendships
    where user_a = least(me, friend) and user_b = greatest(me, friend);
  if not found then
    return 'not_found';
  end if;
  return 'removed';
end;
$$;

grant execute on function public.remove_friend(uuid) to anon, authenticated;

-- ─────────────────────── قائمة الأصدقاء ───────────────────────
-- كل ما تعرضه الشاشة في استدعاء واحد: الاسم والصورة والمستوى والسلسلة
-- وترتيب تحدي اليوم. الترتيب محسوب *داخل دائرتي أنا* (أنا + أصدقائي)
-- لا عالميا: "الثالث بين أصدقائك" رقم يفهمه اللاعب ويستفزّه، بينما
-- "رقم 41,283 عالميا" لا يعني شيئا.
create or replace function public.my_friends(p_date date default null)
returns table (
  friend_id uuid,
  display_name text,
  friend_code text,
  avatar_id text,
  player_level int,
  current_streak int,
  today_score int,
  today_rank bigint,
  circle_size bigint,
  friends_since timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  d date := coalesce(p_date, (now() at time zone 'utc')::date);
begin
  if me is null then
    return;
  end if;

  return query
  with circle as (
    select me as uid, null::timestamptz as since
    union all
    select case when f.user_a = me then f.user_b else f.user_a end, f.accepted_at
    from public.friendships f
    where f.status = 'accepted' and (f.user_a = me or f.user_b = me)
  ),
  scored as (
    select
      c.uid,
      c.since,
      coalesce(r.score, 0) as score,
      r.score is not null as played
    from circle c
    left join public.daily_challenge_results r
      on r.user_id = c.uid and r.date = d
  ),
  ranked as (
    select
      s.*,
      -- من لم يلعب اليوم بلا ترتيب أصلا (null) بدل أن يُحشر في الذيل
      case when s.played
        then rank() over (order by (case when s.played then s.score end) desc nulls last)
      end as rnk
    from scored s
  )
  select
    rk.uid,
    coalesce(p.display_name, 'لاعب'),
    coalesce(p.friend_code, '--------'),
    coalesce(p.avatar_id, 'a1'),
    public.player_level_from_xp(coalesce(p.lifetime_xp, 0)),
    coalesce(st.current_streak, 0),
    rk.score,
    rk.rnk,
    (select count(*) from circle),
    rk.since
  from ranked rk
  left join public.profiles p on p.user_id = rk.uid
  left join public.streaks st on st.user_id = rk.uid
  where rk.uid <> me
  order by rk.rnk nulls last, coalesce(st.current_streak, 0) desc, 2;
end;
$$;

grant execute on function public.my_friends(date) to anon, authenticated;

-- ─────────────────────── إعادة تعريف ما يقرأ friendships ───────────────────────
-- الدالتان التاليتان كانتا تقرآن (user_id, friend_id). محتواهما لم
-- يتغيّر — فقط شرط الدائرة.

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
    select case when f.user_a = me then f.user_b else f.user_a end
    from public.friendships f
    where f.status = 'accepted' and (f.user_a = me or f.user_b = me)
  ),
  scored as (
    select
      c.uid as uid,
      coalesce(p.display_name, 'لاعب') as dname,
      coalesce(p.friend_code, '--------') as fcode,
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
    select case when f.user_a = me then f.user_b else f.user_a end
    from public.friendships f
    where f.status = 'accepted' and (f.user_a = me or f.user_b = me)
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

-- ─────────────────────── الدعوات (v2) ───────────────────────

alter table public.referrals
  add column if not exists status text not null default 'qualified',
  add column if not exists install_id text,
  add column if not exists qualified_at timestamptz,
  add column if not exists referrer_paid_at timestamptz,
  add column if not exists joiner_reward int not null default 0;

-- الصفوف السابقة لهذا الملف دُفع لداعيها فور الاستبدال (سلوك v1)،
-- فنعلّمها مؤهَّلة ومدفوعة حتى لا يُعاد دفعها ولا تُحتسب خطأ كمعلّقة
update public.referrals
  set qualified_at = coalesce(qualified_at, created_at),
      referrer_paid_at = coalesce(referrer_paid_at, created_at)
  where status = 'qualified' and referrer_paid_at is null;

alter table public.referrals
  alter column status set default 'pending';

do $$
begin
  alter table public.referrals
    add constraint referrals_status_check check (status in ('pending', 'qualified'));
exception
  when duplicate_object then null;
end;
$$;

-- استبدال واحد لكل تثبيت. الفرادة على referred_id وحدها لا تكفي: حساب
-- مجهول جديد يُنشأ بمجرد مسح بيانات التطبيق، فيصير كل مسح دعوة جديدة.
-- معرّف التثبيت يُولَّد مرة على الجهاز ويبقى ما بقي التطبيق مثبّتا.
create unique index if not exists referrals_install_idx
  on public.referrals (install_id) where install_id is not null;

create index if not exists referrals_referrer_idx
  on public.referrals (referrer_id);

-- كم دعوة مدفوعة لهذا الحساب (هذا هو ما يقيسه السقف: الناجحة فقط)
create or replace function public.paid_referral_count(target uuid)
returns int
language sql
security definer
set search_path = public
as $$
  select count(*)::int from public.referrals
    where referrer_id = target and referrer_paid_at is not null;
$$;

-- ─────────────────────── مكافآت المراحل الزخرفية ───────────────────────
-- عملات إضافية عند 3 و5 و10 دعوات كانت ستضاعف حافز التزوير على نفس
-- المحور تماما. الزخرفة تُرى ولا تُنفَق: تكافئ الداعي بما لا يفسد
-- اقتصاد اللعبة مهما بلغ عدد دعواته.

create table if not exists public.pending_cosmetics (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  cosmetic_id text not null,
  reason text not null default 'referral_milestone',
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  unique (user_id, cosmetic_id)
);

alter table public.pending_cosmetics enable row level security;

drop policy if exists "pending_cosmetics owner read" on public.pending_cosmetics;
create policy "pending_cosmetics owner read"
  on public.pending_cosmetics for select
  using (auth.uid() = user_id);

create or replace function public.referral_milestones()
returns table (at_count int, cosmetic_id text)
language sql immutable as $$
  values (3, 'invite_milestone_3'), (5, 'invite_milestone_5'), (10, 'invite_milestone_10')
$$;

create or replace function public.grant_referral_milestones(target uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  paid int := public.paid_referral_count(target);
begin
  insert into public.pending_cosmetics (user_id, cosmetic_id, reason)
  select target, m.cosmetic_id, 'referral_milestone'
  from public.referral_milestones() m
  where m.at_count <= paid
  on conflict (user_id, cosmetic_id) do nothing;
end;
$$;

create or replace function public.claim_pending_cosmetics()
returns table (cosmetic_id text)
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
  update public.pending_cosmetics
    set claimed_at = now()
    where user_id = me and claimed_at is null
    returning public.pending_cosmetics.cosmetic_id;
end;
$$;

grant execute on function public.claim_pending_cosmetics() to anon, authenticated;

-- ─────────────────────── تأهيل الدعوة (المرحلة الثانية) ───────────────────────
-- تُستدعى من sync_my_xp أدناه، أي من مسار المدعوّ نفسه فقط. الداعي لا
-- يملك أي طريق لتشغيلها: لا دالة "ادفع لي"، ولا معامل يمرّره.
create or replace function public.try_qualify_referral(joiner uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  rec public.referrals;
  lvl int;
begin
  select * into rec from public.referrals
    where referred_id = joiner and status = 'pending';
  if not found then
    return false;
  end if;

  select public.player_level_from_xp(coalesce(lifetime_xp, 0)) into lvl
    from public.profiles where user_id = joiner;
  if coalesce(lvl, 1) < public.referral_qualify_level() then
    return false;
  end if;

  -- بلغ المستوى فعلا: الدعوة مؤهَّلة دوما، لكن الدفع يتوقّف على السقف.
  -- (المؤهَّلة غير المدفوعة تبقى مرئية للاعب كـ"فوق السقف" بدل اختفائها)
  if public.paid_referral_count(rec.referrer_id) >= public.referral_max_paid_per_account() then
    update public.referrals
      set status = 'qualified', qualified_at = now()
      where id = rec.id;
    return false;
  end if;

  update public.referrals
    set status = 'qualified', qualified_at = now(), referrer_paid_at = now()
    where id = rec.id;

  insert into public.pending_rewards (user_id, amount, reason)
    values (rec.referrer_id, public.referral_reward_referrer(), 'referral');

  perform public.grant_referral_milestones(rec.referrer_id);
  return true;
end;
$$;

-- sync_my_xp مُعاد تعريفها هنا بإضافة سطر واحد: محاولة تأهيل دعوتي بعد
-- تحديث lifetime_xp. هذا هو المسار الوحيد الذي تدخل منه XP إلى الخادم
-- (تصاعديا فقط عبر greatest)، فهو المكان الصحيح لاشتقاق المستوى منه.
create or replace function public.sync_my_xp(new_xp int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  merged int;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  update public.profiles
    set lifetime_xp = greatest(lifetime_xp, coalesce(new_xp, 0))
    where user_id = me
    returning lifetime_xp into merged;

  if merged is null then
    return 0; -- لا ملف بعد (لم يُستدع get_or_create_my_profile)
  end if;

  -- (كان هنا تحديث league_scores/leagues — جدولا الدوري غير موجودين في
  -- هذا المستودع، فكان كل نداء يرمي «relation does not exist» قبل بلوغ
  -- try_qualify_referral، ولا يُدفع لأي داعٍ أبدا.)

  perform public.try_qualify_referral(me);

  return merged;
end;
$$;

grant execute on function public.sync_my_xp(int) to anon, authenticated;

-- ─────────────────────── استبدال رمز الدعوة (v2) ───────────────────────
-- المدعوّ يأخذ مئة فورا (هديّة الترحيب هي ما يجعله يُدخل الرمز أصلا)،
-- والداعي لا يأخذ شيئا الآن — راجع try_qualify_referral أعلاه.
create or replace function public.redeem_referral(code text, p_install_id text default null)
returns table (outcome text, reward int)
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  referrer uuid;
  joined_at timestamptz;
  a uuid;
  b uuid;
begin
  if me is null then
    return query select 'not_authenticated'::text, 0;
    return;
  end if;

  if exists (select 1 from public.referrals where referred_id = me) then
    return query select 'already_redeemed'::text, 0;
    return;
  end if;

  if p_install_id is not null
     and exists (select 1 from public.referrals where install_id = p_install_id) then
    return query select 'install_used'::text, 0;
    return;
  end if;

  select user_id into referrer from public.profiles
    where friend_code = upper(btrim(code));
  if referrer is null then
    return query select 'not_found'::text, 0;
    return;
  end if;
  if referrer = me then
    return query select 'self'::text, 0;
    return;
  end if;

  -- الدعوة للاعبين الجدد: من لعب أسبوعا ثم أدخل رمزا ليس مدعوّا فعلا،
  -- وهذه أبسط طريقة تمنع تبادل الرموز بين القدامى
  select created_at into joined_at from public.profiles where user_id = me;
  if joined_at < now() - interval '7 days' then
    return query select 'too_late'::text, 0;
    return;
  end if;

  if public.paid_referral_count(referrer) >= public.referral_max_paid_per_account() then
    return query select 'cap_reached'::text, 0;
    return;
  end if;

  insert into public.referrals
    (referrer_id, referred_id, install_id, status, joiner_reward)
    values (referrer, me, p_install_id, 'pending', public.referral_reward_joiner());

  -- الصداقة تُقبل تلقائيا بين الداعي والمدعوّ (مع احترام سقف المئتين)
  if public.friend_count_of(referrer) < public.max_friends()
     and public.my_friend_count() < public.max_friends() then
    a := least(referrer, me);
    b := greatest(referrer, me);
    insert into public.friendships (user_a, user_b, requested_by, status, accepted_at)
      values (a, b, referrer, 'accepted', now())
    on conflict on constraint friendships_unique_pair
      do update set status = 'accepted', accepted_at = now();
  end if;

  return query select 'ok'::text, public.referral_reward_joiner();
end;
$$;

grant execute on function public.redeem_referral(text, text) to anon, authenticated;

-- التوقيع القديم (معامل واحد) يبقى كي لا ينكسر عميل قديم لم يُحدَّث بعد
create or replace function public.redeem_referral(code text)
returns table (outcome text, reward int)
language sql
security definer
set search_path = public
as $$
  select * from public.redeem_referral(code, null::text);
$$;

grant execute on function public.redeem_referral(text) to anon, authenticated;

-- ─────────────────────── حالة دعواتي ───────────────────────
create or replace function public.my_referral_status()
returns table (
  invited int,
  qualified int,
  paid int,
  cap int,
  qualify_level int
)
language sql
security definer
set search_path = public
as $$
  select
    (select count(*)::int from public.referrals where referrer_id = auth.uid()),
    (select count(*)::int from public.referrals
       where referrer_id = auth.uid() and status = 'qualified'),
    public.paid_referral_count(auth.uid()),
    public.referral_max_paid_per_account(),
    public.referral_qualify_level();
$$;

grant execute on function public.my_referral_status() to anon, authenticated;

-- my_referral_count تبقى للتوافق، لكنها الآن تعدّ *الناجحة* لا كل من
-- أدخل الرمز — الإنجاز يجب أن يتبع نفس تعريف "دعوة ناجحة" المدفوع عليه
create or replace function public.my_referral_count()
returns int
language sql
security definer
set search_path = public
as $$
  select public.paid_referral_count(auth.uid());
$$;

grant execute on function public.my_referral_count() to anon, authenticated;
