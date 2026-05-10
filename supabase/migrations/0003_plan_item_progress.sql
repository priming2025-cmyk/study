-- Add progress tracking to plan items.
-- Users can update actual_seconds automatically (from sessions) and/or manually.

alter table public.plan_items
  add column if not exists actual_seconds integer not null default 0 check (actual_seconds >= 0),
  add column if not exists is_done boolean not null default false;

create index if not exists plan_items_plan_done_idx on public.plan_items (plan_id, is_done);

