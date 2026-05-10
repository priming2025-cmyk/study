-- Link a study session to a plan item (optional) and store a lightweight subject label.
-- This supports auto-applying focused_seconds to the chosen plan item.

alter table public.study_sessions
  add column if not exists subject text,
  add column if not exists plan_item_id uuid references public.plan_items (id) on delete set null;

create index if not exists study_sessions_plan_item_idx on public.study_sessions (plan_item_id);

