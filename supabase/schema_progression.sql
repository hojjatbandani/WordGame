-- حروف — سكيما نظام التقدّم الجديد (v2: عملات/XP/نجوم منفصلة).
-- شغّل هذا الملف بعد supabase/schema.sql في SQL Editor لمشروعك.
--
-- لا سياسة RLS للكتابة المباشرة على player_progress عمدا (بخلاف
-- profiles التي تسمح بتحديث مباشر) — كل كتابة تمر عبر
-- sync_player_progress كي يبقى شرط "لا يتراجع أي عدّاد أبدا" مضمونا في
-- قاعدة البيانات نفسها، لا في العميل وحده الذي قد يحمل علة أو نسخة
-- قديمة. نفس نمط multiplayer_rooms في schema_social.sql بالضبط.
--
-- ملاحظة تصميم مهمة: هذه الدالة حارس أمان إضافي للأرقام الثلاثة السهلة
-- القياس (coins/xp/totalStars) عبر greatest() — تماما كـsync_my_score
-- الموجودة فعلا في schema_social.sql. هي ليست محرّك الدمج التفصيلي لكل
-- حقل في كل مرحلة (النجوم لكل مرحلة، الكلمات الإضافية المكتشفة..)؛ ذاك
-- الدمج التفصيلي يعيش في lib/data/progression/progression_merge.dart
-- ومُختبَر بوحدات هناك. سبب الفصل: لا قاعدة بيانات فعلية متاحة هنا
-- لتشغيل واختبار دمج JSONB متداخل ومركّب بثقة، بينما دمج Dart قابل
-- للاختبار الآن فورا. العميل يجلب ثم يدمج محليا (بالدالة المُختبَرة) ثم
-- يرفع، وهذه الدالة تمنع فقط أي رفع يمثّل تراجعا واضحا في المجاميع.

create table if not exists public.player_progress (
  user_id uuid primary key references auth.users (id) on delete cascade,
  state_json jsonb not null,
  stage_progress_json jsonb not null default '{}'::jsonb,
  client_version int not null default 1,
  updated_at timestamptz not null default now()
);

alter table public.player_progress enable row level security;

drop policy if exists "player_progress owner read" on public.player_progress;
create policy "player_progress owner read"
  on public.player_progress for select
  using (auth.uid() = user_id);

-- يجلب صفّ اللاعب الحالي، أو null إن لم يزامن قط
create or replace function public.fetch_my_player_progress()
returns public.player_progress
language sql
security definer
set search_path = public
as $$
  select * from public.player_progress where user_id = auth.uid();
$$;

grant execute on function public.fetch_my_player_progress() to anon, authenticated;

-- يدمج ويكتب تقدّم اللاعب. راجع الملاحظة أعلى الملف لحدود هذا الحارس.
create or replace function public.sync_player_progress(
  new_state jsonb,
  new_stage_progress jsonb,
  new_client_version int
)
returns public.player_progress
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  existing public.player_progress;
  merged_state jsonb;
  incoming_stars int;
  stored_stars int;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;

  incoming_stars := coalesce((new_state -> 'wallet' ->> 'totalStars')::int, 0);

  select * into existing from public.player_progress where user_id = me;

  if not found then
    insert into public.player_progress (user_id, state_json, stage_progress_json, client_version)
    values (me, new_state, new_stage_progress, new_client_version)
    returning * into existing;
    return existing;
  end if;

  stored_stars := coalesce((existing.state_json -> 'wallet' ->> 'totalStars')::int, 0);

  -- حارس عدم التراجع: دفعة أقل نجوما مما هو محفوظ فعلا على الأرجح
  -- جهاز لم يُزامن آخر تقدّم بعد — تُرفض بهدوء ويُعاد الصف الحالي، كي
  -- يعيد العميل الدمج محليا (فيضم آخر ما لديه) ويحاول من جديد، بدل أن
  -- تُطبَّق خطوة إلى الوراء فعليا في قاعدة البيانات
  if incoming_stars < stored_stars then
    return existing;
  end if;

  -- دمج أمان إضافي على الأرقام الثلاثة، حتى لو نسي العميل دمجها محليا
  -- قبل الإرسال (العميل السليم يرسلها مدموجة أصلا فهذا لا يغيّر شيئا
  -- في المسار الطبيعي)
  merged_state := jsonb_set(
    jsonb_set(
      jsonb_set(
        new_state,
        '{wallet,coins}',
        to_jsonb(greatest(
          coalesce((new_state -> 'wallet' ->> 'coins')::int, 0),
          coalesce((existing.state_json -> 'wallet' ->> 'coins')::int, 0)
        ))
      ),
      '{wallet,xp}',
      to_jsonb(greatest(
        coalesce((new_state -> 'wallet' ->> 'xp')::int, 0),
        coalesce((existing.state_json -> 'wallet' ->> 'xp')::int, 0)
      ))
    ),
    '{wallet,totalStars}',
    to_jsonb(greatest(incoming_stars, stored_stars))
  );

  update public.player_progress
    set state_json = merged_state,
        stage_progress_json = new_stage_progress,
        client_version = new_client_version,
        updated_at = now()
    where user_id = me
    returning * into existing;

  return existing;
end;
$$;

grant execute on function public.sync_player_progress(jsonb, jsonb, int) to anon, authenticated;
