-- حروف — سكيما التحدي اليومي (Feature 1: Daily Challenge)
-- شغّل هذا الملف كاملا مرة واحدة في SQL Editor لمشروع Supabase الخاص بك
-- (Dashboard → SQL Editor → New query → الصق والصق ثم Run).
-- يفترض استخدام Anonymous Auth (auth.uid() متاح لأي جلسة، مسجلة أو لا).

-- ─────────────────────── جدول مخزون الألغاز اليومية ───────────────────────
-- عيّنة ثابتة من الألغاز (مصدّرة من levels.json عبر tool/export_daily_pool.dart)
-- يختار منها get_or_create_daily_challenge لغزا واحدا محدَّدا بحتمية لكل يوم UTC
create table if not exists public.daily_puzzle_pool (
  id bigint generated always as identity primary key,
  puzzle_data jsonb not null
);

-- ─────────────────────── تحدي اليوم المشترك ───────────────────────
create table if not exists public.daily_challenges (
  challenge_date date primary key default (now() at time zone 'utc')::date,
  puzzle_data jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.daily_challenges enable row level security;

drop policy if exists "daily_challenges readable by everyone" on public.daily_challenges;
create policy "daily_challenges readable by everyone"
  on public.daily_challenges for select
  using (true);

-- ─────────────────────── محاولة كل مستخدم لكل يوم ───────────────────────
-- UNIQUE(user_id, challenge_date) هو مصدر الحقيقة لقاعدة "مرة واحدة في اليوم"
create table if not exists public.daily_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  challenge_date date not null references public.daily_challenges (challenge_date),
  result jsonb not null, -- {"words":[{"word":"...", "status":"solved|hinted|missed"}], "attempts": n}
  created_at timestamptz not null default now(),
  unique (user_id, challenge_date)
);

alter table public.daily_attempts enable row level security;

drop policy if exists "daily_attempts owner read" on public.daily_attempts;
create policy "daily_attempts owner read"
  on public.daily_attempts for select
  using (auth.uid() = user_id);

drop policy if exists "daily_attempts owner insert" on public.daily_attempts;
create policy "daily_attempts owner insert"
  on public.daily_attempts for insert
  with check (auth.uid() = user_id);

-- ─────────────────────── الستريك ───────────────────────
create table if not exists public.streaks (
  user_id uuid primary key references auth.users (id) on delete cascade,
  current_streak int not null default 0,
  best_streak int not null default 0,
  last_played_date date
);

alter table public.streaks enable row level security;

drop policy if exists "streaks owner read" on public.streaks;
create policy "streaks owner read"
  on public.streaks for select
  using (auth.uid() = user_id);

-- لا سياسة insert/update مباشرة للمستخدم: يُحدَّث الستريك فقط عبر التريغر
-- أدناه بصلاحية SECURITY DEFINER كي لا يستطيع أحد التلاعب برقمه

-- ─────────────────────── تريغر تحديث الستريك ───────────────────────
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
    values (new.user_id, 1, 1, new.challenge_date);
  elsif prev = new.challenge_date - 1 then
    update public.streaks
      set current_streak = current_streak + 1,
          best_streak = greatest(best_streak, current_streak + 1),
          last_played_date = new.challenge_date
      where user_id = new.user_id;
  elsif prev = new.challenge_date then
    -- محاولة مكررة لنفس اليوم (لا يجب أن يحدث بسبب UNIQUE، احتياط فقط)
    null;
  else
    update public.streaks
      set current_streak = 1,
          best_streak = greatest(best_streak, 1),
          last_played_date = new.challenge_date
      where user_id = new.user_id;
  end if;

  return new;
end;
$$;

drop trigger if exists on_daily_attempt_insert on public.daily_attempts;
create trigger on_daily_attempt_insert
  after insert on public.daily_attempts
  for each row execute function public.handle_daily_attempt();

-- ─────────────────────── دالة: أحضر تحدي اليوم أو أنشئه ───────────────────────
-- استراتيجية "كسولة" (lazy): يُنشأ عند أول طلب في اليوم بدلا من cron —
-- أبسط لهذا الحجم من المشروع ولا يحتاج جدولة Edge Function منفصلة
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
  select * into existing from public.daily_challenges where challenge_date = today;
  if found then
    return existing;
  end if;

  select count(*) into pool_count from public.daily_puzzle_pool;
  if pool_count = 0 then
    raise exception 'daily_puzzle_pool is empty — run tool/daily_pool_seed.sql first';
  end if;

  -- اختيار حتمي لكل يوم UTC (نفس اليوم = نفس اللغز لكل المستخدمين)
  pick := (('x' || substr(md5(today::text), 1, 8))::bit(32)::int % pool_count);
  if pick < 0 then pick := pick + pool_count; end if;

  select puzzle_data into chosen from public.daily_puzzle_pool offset pick limit 1;

  insert into public.daily_challenges (challenge_date, puzzle_data)
  values (today, chosen)
  on conflict (challenge_date) do nothing
  returning * into existing;

  if existing.challenge_date is null then
    select * into existing from public.daily_challenges where challenge_date = today;
  end if;

  return existing;
end;
$$;

grant execute on function public.get_or_create_daily_challenge() to anon, authenticated;

-- ─────────────────────── تعبئة مخزون الألغاز ───────────────────────
-- الصق محتوى tool/daily_pool_seed.sql هنا (أو شغّله بعد هذا الملف مباشرة)
