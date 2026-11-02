-- حروف — سكيما الأصدقاء واللوحة والتحدي الثنائي (Features 3 & 4)
-- شغّل هذا الملف بعد supabase/schema.sql في SQL Editor لمشروعك.
-- كل الاستعلامات الحسّاسة تمر عبر دوال SECURITY DEFINER كي تبقى سياسات
-- RLS ضيّقة (المستخدم يقرأ صفّه فقط) دون منع اللوحة من رؤية الأصدقاء.

-- ─────────────────────── ملف اللاعب ───────────────────────
create table if not exists public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  friend_code text unique not null,
  display_name text not null default 'لاعب',
  total_score int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles owner read" on public.profiles;
create policy "profiles owner read"
  on public.profiles for select
  using (auth.uid() = user_id);

drop policy if exists "profiles owner update" on public.profiles;
create policy "profiles owner update"
  on public.profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- رمز صديق من 6 محارف، بلا أحرف/أرقام ملتبسة (0/O، 1/I) كي يسهل نطقه
-- وكتابته يدويا — فلا حاجة لروابط عميقة إطلاقا
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
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.profiles where friend_code = code);
  end loop;
  return code;
end;
$$;

-- يُستدعى عند إقلاع التطبيق: ينشئ الملف عند أول مرة ويعيده بعدها.
-- أفضل من تريغر على auth.users لأنه يغطي أيضا الحسابات المنشأة سابقا.
create or replace function public.get_or_create_my_profile()
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  rec public.profiles;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  select * into rec from public.profiles where user_id = me;
  if found then
    return rec;
  end if;

  insert into public.profiles (user_id, friend_code)
  values (me, public.generate_friend_code())
  on conflict (user_id) do nothing;

  select * into rec from public.profiles where user_id = me;
  return rec;
end;
$$;

grant execute on function public.get_or_create_my_profile() to anon, authenticated;

-- مزامنة النقاط المحلية إلى اللوحة (المصدر يبقى الجهاز، واللوحة مرآة)
create or replace function public.sync_my_score(new_score int)
returns void
language sql
security definer
set search_path = public
as $$
  update public.profiles
    set total_score = greatest(total_score, new_score)
    where user_id = auth.uid();
$$;

grant execute on function public.sync_my_score(int) to anon, authenticated;

-- ─────────────────────── الصداقات ───────────────────────
create table if not exists public.friendships (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  friend_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  unique (user_id, friend_id),
  check (user_id <> friend_id)
);

alter table public.friendships enable row level security;

drop policy if exists "friendships visible to both sides" on public.friendships;
create policy "friendships visible to both sides"
  on public.friendships for select
  using (auth.uid() = user_id or auth.uid() = friend_id);

-- القبول: الطرف المستقبِل فقط يحوّل الحالة إلى accepted
drop policy if exists "friendships receiver accepts" on public.friendships;
create policy "friendships receiver accepts"
  on public.friendships for update
  using (auth.uid() = friend_id)
  with check (auth.uid() = friend_id);

-- إضافة صديق برمزه — SECURITY DEFINER كي لا نفتح قراءة كل الملفات
-- للبحث عن الرمز (منعا لتعداد المستخدمين)
create or replace function public.add_friend_by_code(code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  target uuid;
begin
  if me is null then
    return 'not_authenticated';
  end if;

  select user_id into target from public.profiles
    where friend_code = upper(trim(code));
  if target is null then
    return 'not_found';
  end if;
  if target = me then
    return 'self';
  end if;

  -- إن كان الطرف الآخر قد أرسل طلبا سابقا، فهذه موافقة عليه
  if exists (select 1 from public.friendships
             where user_id = target and friend_id = me and status = 'pending') then
    update public.friendships set status = 'accepted'
      where user_id = target and friend_id = me;
    return 'accepted';
  end if;

  if exists (select 1 from public.friendships
             where (user_id = me and friend_id = target)
                or (user_id = target and friend_id = me)) then
    return 'exists';
  end if;

  insert into public.friendships (user_id, friend_id) values (me, target);
  return 'sent';
end;
$$;

grant execute on function public.add_friend_by_code(text) to anon, authenticated;

-- طلبات الصداقة الواردة المعلّقة (مع اسم المرسل ورمزه)
create or replace function public.my_pending_requests()
returns table (friendship_id bigint, from_name text, from_code text)
language sql
security definer
set search_path = public
as $$
  select f.id, coalesce(p.display_name, 'لاعب'), coalesce(p.friend_code, '------')
  from public.friendships f
  left join public.profiles p on p.user_id = f.user_id
  where f.friend_id = auth.uid() and f.status = 'pending'
  order by f.created_at desc;
$$;

grant execute on function public.my_pending_requests() to anon, authenticated;

create or replace function public.accept_friend_request(request_id bigint)
returns void
language sql
security definer
set search_path = public
as $$
  update public.friendships set status = 'accepted'
    where id = request_id and friend_id = auth.uid() and status = 'pending';
$$;

grant execute on function public.accept_friend_request(bigint) to anon, authenticated;

-- ─────────────────────── لوحة الأصدقاء ───────────────────────
-- metric: 'streak' سلسلة الأيام | 'weekly' كلمات هذا الأسبوع | 'score' المجموع
-- ملاحظة: أسماء الأعمدة تتجنب كلمات Postgres المحجوزة (position/row/value)
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
    -- اللاعب نفسه + كل صداقة مقبولة من الطرفين
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
      -- عمود واحد يحمل قيمة المعيار المطلوب أيا كان، فيبقى الترتيب موحّدا
      case metric
        when 'streak' then coalesce(s.current_streak, 0)
        when 'weekly' then coalesce((
          select sum((
            select count(*) from jsonb_array_elements(a.result -> 'words') w
            where w ->> 'status' <> 'missed'
          ))
          from public.daily_attempts a
          where a.user_id = c.uid
            and a.challenge_date >= date_trunc('week', (now() at time zone 'utc'))::date
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

-- ─────────────────────── غرف التحدي الثنائي ───────────────────────
create table if not exists public.multiplayer_rooms (
  id bigint generated always as identity primary key,
  room_code text unique not null,
  host_id uuid not null references auth.users (id) on delete cascade,
  guest_id uuid references auth.users (id) on delete cascade,
  puzzle_data jsonb not null,
  host_result jsonb,
  guest_result jsonb,
  status text not null default 'waiting'
    check (status in ('waiting', 'active', 'complete')),
  created_at timestamptz not null default now()
);

alter table public.multiplayer_rooms enable row level security;

-- طرفا الغرفة فقط يقرآنها؛ الانضمام يتم عبر دالة أدناه لأن الضيف لا يملك
-- صلاحية القراءة قبل أن يصبح guest_id
drop policy if exists "rooms visible to players" on public.multiplayer_rooms;
create policy "rooms visible to players"
  on public.multiplayer_rooms for select
  using (auth.uid() = host_id or auth.uid() = guest_id);

create or replace function public.create_room()
returns public.multiplayer_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
  i int;
  chosen jsonb;
  pool_count int;
  rec public.multiplayer_rooms;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  select count(*) into pool_count from public.daily_puzzle_pool;
  if pool_count = 0 then
    raise exception 'daily_puzzle_pool is empty — run tool/daily_pool_seed.sql first';
  end if;
  select puzzle_data into chosen from public.daily_puzzle_pool
    offset floor(random() * pool_count)::int limit 1;

  loop
    code := '';
    for i in 1..5 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.multiplayer_rooms where room_code = code);
  end loop;

  insert into public.multiplayer_rooms (room_code, host_id, puzzle_data)
  values (code, me, chosen)
  returning * into rec;
  return rec;
end;
$$;

grant execute on function public.create_room() to anon, authenticated;

create or replace function public.join_room(code text)
returns public.multiplayer_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  rec public.multiplayer_rooms;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  select * into rec from public.multiplayer_rooms
    where room_code = upper(trim(code));
  if rec.id is null then
    raise exception 'room_not_found';
  end if;
  if rec.host_id = me then
    return rec; -- المضيف يعيد فتح غرفته
  end if;
  if rec.guest_id is not null and rec.guest_id <> me then
    raise exception 'room_full';
  end if;

  update public.multiplayer_rooms
    set guest_id = me, status = 'active'
    where id = rec.id
    returning * into rec;
  return rec;
end;
$$;

grant execute on function public.join_room(text) to anon, authenticated;

create or replace function public.submit_room_result(code text, result jsonb)
returns public.multiplayer_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  rec public.multiplayer_rooms;
begin
  select * into rec from public.multiplayer_rooms
    where room_code = upper(trim(code));
  if rec.id is null then
    raise exception 'room_not_found';
  end if;

  if rec.host_id = me then
    update public.multiplayer_rooms set host_result = result
      where id = rec.id returning * into rec;
  elsif rec.guest_id = me then
    update public.multiplayer_rooms set guest_result = result
      where id = rec.id returning * into rec;
  else
    raise exception 'not_a_player';
  end if;

  if rec.host_result is not null and rec.guest_result is not null then
    update public.multiplayer_rooms set status = 'complete'
      where id = rec.id returning * into rec;
  end if;

  return rec;
end;
$$;

grant execute on function public.submit_room_result(text, jsonb) to anon, authenticated;

-- تفعيل البث اللحظي على الغرف كي تتحدث شاشة كل لاعب فور انتهاء الآخر
do $$
begin
  alter publication supabase_realtime add table public.multiplayer_rooms;
exception
  when duplicate_object then null;
end;
$$;
