-- حروف — الدعوات والمكافآت واللوحة العالمية
-- شغّله بعد schema.sql و schema_social.sql في SQL Editor.

-- ─────────────────────── الاسم الظاهر ───────────────────────
-- اللوحة العالمية بلا أسماء بلا معنى، فنسمح للاعب باختيار اسمه.
-- التنظيف هنا مقصود: لا مسافات طرفية، وحد أقصى 20 محرفا، ولا اسم فارغ.
create or replace function public.set_display_name(new_name text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  cleaned text := btrim(new_name);
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if length(cleaned) = 0 then
    return 'empty';
  end if;
  cleaned := left(cleaned, 20);

  update public.profiles set display_name = cleaned where user_id = auth.uid();
  return cleaned;
end;
$$;

grant execute on function public.set_display_name(text) to anon, authenticated;

-- ─────────────────────── مكافآت معلّقة ───────────────────────
-- الداعي قد يكون مغلقا تطبيقه لحظة انضمام صديقه، ونقاطه محفوظة على
-- جهازه لا في السحابة. لذلك نضع له مكافأة معلّقة يستلمها عند أول فتح.
create table if not exists public.pending_rewards (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  amount int not null check (amount > 0),
  reason text not null,
  created_at timestamptz not null default now(),
  claimed_at timestamptz
);

create index if not exists pending_rewards_unclaimed_idx
  on public.pending_rewards (user_id) where claimed_at is null;

alter table public.pending_rewards enable row level security;

drop policy if exists "pending_rewards owner read" on public.pending_rewards;
create policy "pending_rewards owner read"
  on public.pending_rewards for select
  using (auth.uid() = user_id);

-- يسلّم كل المكافآت غير المستلمة دفعة واحدة ويعيد مجموعها.
-- التحديث نفسه يعلّمها مستلمة، فلا يمكن استلامها مرتين.
create or replace function public.claim_pending_rewards()
returns table (total int, count int)
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    return query select 0, 0;
    return;
  end if;

  return query
  with claimed as (
    update public.pending_rewards
      set claimed_at = now()
      where user_id = me and claimed_at is null
      returning amount
  )
  select coalesce(sum(amount), 0)::int, count(*)::int from claimed;
end;
$$;

grant execute on function public.claim_pending_rewards() to anon, authenticated;

-- ─────────────────────── الدعوات ───────────────────────
create table if not exists public.referrals (
  id bigint generated always as identity primary key,
  referrer_id uuid not null references auth.users (id) on delete cascade,
  -- قيد الفرادة على المدعوّ: كل لاعب يُدعى مرة واحدة في حياته فقط،
  -- وهذا هو ما يمنع استغلال النظام لا فحص في التطبيق
  referred_id uuid not null unique references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  check (referrer_id <> referred_id)
);

alter table public.referrals enable row level security;

drop policy if exists "referrals visible to both" on public.referrals;
create policy "referrals visible to both"
  on public.referrals for select
  using (auth.uid() = referrer_id or auth.uid() = referred_id);

-- مكافأة الطرفين
create or replace function public.referral_reward_referrer() returns int
  language sql immutable as $$ select 150 $$;
create or replace function public.referral_reward_joiner() returns int
  language sql immutable as $$ select 100 $$;

-- يستبدل المدعوُّ رمز صديقه: يمنحه نقاطه فورا، ويترك للداعي مكافأة
-- معلّقة يستلمها لاحقا.
create or replace function public.redeem_referral(code text)
returns table (outcome text, reward int)
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  referrer uuid;
  joined_at timestamptz;
begin
  if me is null then
    return query select 'not_authenticated'::text, 0;
    return;
  end if;

  if exists (select 1 from public.referrals where referred_id = me) then
    return query select 'already_redeemed'::text, 0;
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

  -- نافذة زمنية: الدعوة للاعبين الجدد. من لعب أسبوعا ثم أدخل رمزا
  -- ليس مدعوّا فعلا، وهذه أبسط طريقة لمنع تبادل الرموز بين القدامى.
  select created_at into joined_at from public.profiles where user_id = me;
  if joined_at < now() - interval '7 days' then
    return query select 'too_late'::text, 0;
    return;
  end if;

  insert into public.referrals (referrer_id, referred_id) values (referrer, me);

  insert into public.pending_rewards (user_id, amount, reason)
  values (referrer, public.referral_reward_referrer(), 'referral');

  -- الصداقة تُقبل تلقائيا بين الداعي والمدعوّ
  insert into public.friendships (user_id, friend_id, status)
  values (referrer, me, 'accepted')
  on conflict (user_id, friend_id) do update set status = 'accepted';

  return query select 'ok'::text, public.referral_reward_joiner();
end;
$$;

grant execute on function public.redeem_referral(text) to anon, authenticated;

-- كم شخصا دعوت؟ (لإنجاز الدعوات وعرضه في الواجهة)
create or replace function public.my_referral_count()
returns int
language sql
security definer
set search_path = public
as $$
  select count(*)::int from public.referrals where referrer_id = auth.uid();
$$;

grant execute on function public.my_referral_count() to anon, authenticated;

-- ─────────────────────── اللوحة العالمية ───────────────────────
-- تعرض أفضل اللاعبين عالميا، وتُلحق صفّ اللاعب نفسه دائما حتى لو كان
-- خارج القائمة كي يرى ترتيبه الحقيقي.
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
          select sum((
            select count(*) from jsonb_array_elements(a.result -> 'words') w
            where w ->> 'status' <> 'missed'
          ))
          from public.daily_attempts a
          where a.user_id = p.user_id
            and a.challenge_date >= date_trunc('week', (now() at time zone 'utc'))::date
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
  -- أفضل N، بالإضافة إلى صفّ اللاعب نفسه إن كان خارجهم
  select r.uid, r.dname,
         -- رمز الصديق لا يُكشف للغرباء: يظهر للاعب نفسه فقط
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
