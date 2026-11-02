-- حروف — ناقل الأحداث والإعداد عن بعد
--
-- شغّله بعد بقية ملفات السكيما في SQL Editor.
--
-- مبدأ التصميم: الجدول واسع بالحقول التي تُقطَع بها كل التقارير تقريبا
-- (المستوى، المرحلة، الرصيد)، وضيّق في JSONB لما يخصّ كل حدث وحده.
-- وضع كل شيء في JSONB يجعل أهمّ خمسة تقارير بطيئة وهشّة، ووضع كل شيء
-- في أعمدة يجعل كل حدث جديد ترحيلا للسكيما.

-- ─────────────────────── جدول الأحداث ───────────────────────
create table if not exists public.events (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete set null,
  session_id text not null,
  event_name text not null,
  properties jsonb not null default '{}'::jsonb,
  -- ساعة الجهاز: قد تكون خاطئة (اللاعب يغيّرها، أو منطقة زمنية غريبة)
  client_ts timestamptz not null,
  -- ساعة الخادم: هي المرجع في كل التقارير الزمنية أدناه
  server_ts timestamptz not null default now(),
  app_version text,
  player_level int,
  stage_id int,
  coin_balance int
);

create index if not exists events_name_time_idx
  on public.events (event_name, server_ts desc);
create index if not exists events_user_time_idx
  on public.events (user_id, server_ts desc);
create index if not exists events_stage_idx
  on public.events (stage_id) where stage_id is not null;

alter table public.events enable row level security;

-- اللاعب يقرأ أحداثه فقط. التحليل يتم بدور الخدمة (service_role) الذي
-- يتجاوز RLS — لا داعي لفتح القراءة لأحد.
drop policy if exists "events owner read" on public.events;
create policy "events owner read"
  on public.events for select
  using (auth.uid() = user_id);

-- لا سياسة insert مباشرة: الإدراج عبر الدالة أدناه وحدها، كي يُفرض
-- user_id من الجلسة لا من العميل، ويُحدَّد حجم الدفعة.

-- ─────────────────────── إدراج دفعة ───────────────────────
-- دفعة واحدة لكل استدعاء بدل صفّ لكل حدث: التطبيق يجمع 30 حدثا ثم يرسل
-- مرة واحدة، فالفرق بين نداء واحد وثلاثين نداء على شبكة جوّال حقيقي.
create or replace function public.ingest_events(p_events jsonb)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  inserted int;
begin
  if p_events is null or jsonb_typeof(p_events) <> 'array' then
    return 0;
  end if;
  -- حارس ضد دفعة ضخمة (عميل معطوب أو محاولة إغراق)
  if jsonb_array_length(p_events) > 200 then
    raise exception 'batch too large';
  end if;

  with rows as (
    select
      me as user_id,
      coalesce(e ->> 'session_id', '') as session_id,
      e ->> 'event_name' as event_name,
      coalesce(e -> 'properties', '{}'::jsonb) as properties,
      coalesce((e ->> 'client_ts')::timestamptz, now()) as client_ts,
      e ->> 'app_version' as app_version,
      (e ->> 'player_level')::int as player_level,
      (e ->> 'stage_id')::int as stage_id,
      (e ->> 'coin_balance')::int as coin_balance
    from jsonb_array_elements(p_events) e
    where e ->> 'event_name' is not null
  ),
  ins as (
    insert into public.events
      (user_id, session_id, event_name, properties, client_ts,
       app_version, player_level, stage_id, coin_balance)
    select * from rows
    returning 1
  )
  select count(*)::int into inserted from ins;

  return inserted;
end;
$$;

grant execute on function public.ingest_events(jsonb) to anon, authenticated;

-- ═══════════════════ الخمسة التي تهمّ فعلا ═══════════════════
-- كل ما عداها ثانوي. هذه الخمس فقط لها عروض جاهزة.

-- ── 1) معدّل الفشل والتخلّي لكل مرحلة ──
-- أعلى تقرير قيمة في المشروع كله: أي مرحلة تجاوز تخلّيها 15% ليست
-- «صعبة» بل معطوبة، وتُعاد كتابتها. العمود needs_rewrite يقول ذلك
-- صراحة بدل ترك القارئ يحسب.
create or replace view public.v_stage_difficulty as
with per_stage as (
  select
    stage_id,
    count(*) filter (where event_name = 'stage_start') as starts,
    count(*) filter (where event_name = 'stage_complete') as completes,
    count(*) filter (where event_name = 'stage_fail') as fails,
    count(*) filter (where event_name = 'stage_abandon') as abandons
  from public.events
  where stage_id is not null
  group by stage_id
)
select
  stage_id,
  starts,
  completes,
  fails,
  abandons,
  round(fails::numeric / nullif(starts, 0), 4) as fail_rate,
  round(abandons::numeric / nullif(starts, 0), 4) as abandon_rate,
  (abandons::numeric / nullif(starts, 0)) > 0.15 as needs_rewrite
from per_stage
order by abandon_rate desc nulls last;

-- ── 2) وسيط رصيد العملات عند اليوم 1 و7 و30 ──
-- النطاق المستهدف 300-800. أقلّ منه يعني اقتصادا خانقا يدفع للتوقّف،
-- وأكثر منه يعني أن لا شيء يستحق الإنفاق.
create or replace view public.v_coin_balance_by_day as
with first_seen as (
  select user_id, min(server_ts) as joined_at
  from public.events
  where user_id is not null
  group by user_id
),
daily as (
  select
    e.user_id,
    floor(extract(epoch from (e.server_ts - f.joined_at)) / 86400)::int as day_n,
    e.coin_balance,
    row_number() over (
      partition by e.user_id,
        floor(extract(epoch from (e.server_ts - f.joined_at)) / 86400)::int
      order by e.server_ts desc
    ) as rn
  from public.events e
  join first_seen f on f.user_id = e.user_id
  where e.coin_balance is not null
)
select
  day_n,
  count(*) as players,
  percentile_cont(0.5) within group (order by coin_balance)::int as median_balance,
  percentile_cont(0.5) within group (order by coin_balance)
    between 300 and 800 as in_target_band
from daily
where rn = 1 and day_n in (1, 7, 30)
group by day_n
order by day_n;

-- ── 3) نسبة المصدر إلى المصرف أسبوعيا ──
-- النطاق المستهدف 1.10-1.30: يدخل أكثر ممّا يخرج بقليل. أقلّ من 1
-- يعني اقتصادا ينكمش، وأكثر من 1.4 يعني تضخّما يُفقد العملة معناها.
create or replace view public.v_faucet_sink_weekly as
with weekly as (
  select
    date_trunc('week', server_ts)::date as week_start,
    sum((properties ->> 'amount')::numeric)
      filter (where event_name = 'coins_earned') as faucet,
    sum((properties ->> 'amount')::numeric)
      filter (where event_name = 'coins_spent') as sink
  from public.events
  where event_name in ('coins_earned', 'coins_spent')
    and properties ? 'amount'
  group by 1
)
select
  week_start,
  coalesce(faucet, 0) as faucet,
  coalesce(sink, 0) as sink,
  round(coalesce(faucet, 0) / nullif(sink, 0), 3) as ratio,
  (coalesce(faucet, 0) / nullif(sink, 0)) between 1.10 and 1.30 as in_target_band
from weekly
order by week_start desc;

-- ── 4) التلميحات لكل مرحلة، حسب العالم ──
-- ارتفاع حادّ بين عالم وآخر = قفزة صعوبة، لا تدرّج.
create or replace view public.v_hints_per_stage_by_world as
with stage_world as (
  -- العوالم 1-4 فيها 60 مرحلة، و5-8 فيها 65 — نفس تقسيم
  -- BalanceConfig.worldStageCount
  select
    stage_id,
    case
      when stage_id <= 240 then ceil(stage_id / 60.0)::int
      else 4 + ceil((stage_id - 240) / 65.0)::int
    end as world_id
  from (select distinct stage_id from public.events where stage_id is not null) s
),
counts as (
  select
    w.world_id,
    count(*) filter (where e.event_name = 'hint_used') as hints,
    count(*) filter (where e.event_name = 'stage_start') as starts
  from public.events e
  join stage_world w on w.stage_id = e.stage_id
  group by w.world_id
)
select
  world_id,
  hints,
  starts,
  round(hints::numeric / nullif(starts, 0), 3) as hints_per_stage
from counts
order by world_id;

-- ── 5) الاحتفاظ في اليوم 1 و7 و30 ──
create or replace view public.v_retention as
with cohort as (
  select user_id, min(server_ts)::date as cohort_day
  from public.events
  where user_id is not null
  group by user_id
),
activity as (
  select distinct e.user_id, c.cohort_day, e.server_ts::date as active_day
  from public.events e
  join cohort c on c.user_id = e.user_id
)
select
  c.cohort_day,
  count(distinct c.user_id) as cohort_size,
  round(count(distinct a1.user_id)::numeric
        / nullif(count(distinct c.user_id), 0), 4) as d1,
  round(count(distinct a7.user_id)::numeric
        / nullif(count(distinct c.user_id), 0), 4) as d7,
  round(count(distinct a30.user_id)::numeric
        / nullif(count(distinct c.user_id), 0), 4) as d30
from cohort c
left join activity a1
  on a1.user_id = c.user_id and a1.active_day = c.cohort_day + 1
left join activity a7
  on a7.user_id = c.user_id and a7.active_day = c.cohort_day + 7
left join activity a30
  on a30.user_id = c.user_id and a30.active_day = c.cohort_day + 30
group by c.cohort_day
order by c.cohort_day desc;

-- ═══════════════════ الإعداد عن بعد ═══════════════════
create table if not exists public.remote_config (
  key text primary key,
  value_json jsonb not null,
  -- أقل نسخة تطبيق تفهم هذا المفتاح. نسخة أقدم لا تستلمه إطلاقا، فلا
  -- تُطبَّق قيمة تخصّ ميزة لا توجد فيها.
  min_app_version text,
  updated_at timestamptz not null default now()
);

alter table public.remote_config enable row level security;

-- الإعداد يُقرأ عبر الدالة أدناه فقط (ترشيح النسخة يقع هناك)

-- مقارنة نسخ دلالية بسيطة: "1.2.10" أحدث من "1.2.9"
create or replace function public.version_gte(a text, b text)
returns boolean
language plpgsql
immutable
as $$
declare
  pa int[];
  pb int[];
  i int;
begin
  if a is null then return false; end if;
  if b is null then return true; end if;
  pa := string_to_array(split_part(a, '+', 1), '.')::int[];
  pb := string_to_array(split_part(b, '+', 1), '.')::int[];
  for i in 1..3 loop
    if coalesce(pa[i], 0) > coalesce(pb[i], 0) then return true; end if;
    if coalesce(pa[i], 0) < coalesce(pb[i], 0) then return false; end if;
  end loop;
  return true;
exception
  -- نصّ نسخة غير متوقّع: نعطي المفتاح بدل حجبه — الافتراضات المُصرَّفة
  -- في التطبيق هي الحارس الأخير على أي حال
  when others then return true;
end;
$$;

create or replace function public.get_remote_config(p_app_version text default null)
returns table (key text, value jsonb)
language sql
security definer
set search_path = public
as $$
  select rc.key, rc.value_json
  from public.remote_config rc
  where rc.min_app_version is null
     or p_app_version is null
     or public.version_gte(p_app_version, rc.min_app_version);
$$;

grant execute on function public.get_remote_config(text) to anon, authenticated;

-- ─────────────────────── مفاتيح الإيقاف ───────────────────────
-- تُزرع مُشغَّلة. قيمتها الافتراضية في التطبيق «مُشغَّل» أيضا، فحذف
-- الصفّ أو تعذّر الوصول لا يطفئ شيئا.
insert into public.remote_config (key, value_json) values
  ('ads_interstitial_enabled', 'true'::jsonb),
  ('ads_rewarded_enabled', 'true'::jsonb),
  ('duel_enabled', 'true'::jsonb),
  ('league_enabled', 'true'::jsonb),
  ('daily_challenge_enabled', 'true'::jsonb),
  ('store_enabled', 'true'::jsonb),
  ('referral_enabled', 'true'::jsonb)
on conflict (key) do nothing;
