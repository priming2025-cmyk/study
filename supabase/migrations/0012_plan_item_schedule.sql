-- Optional start time + reminder flag for plan items (local notifications use these).

alter table public.plan_items
  add column if not exists scheduled_start_at timestamptz,
  add column if not exists reminder_enabled boolean not null default false;

comment on column public.plan_items.scheduled_start_at is 'When the user intends to start this block (device-local instant stored as timestamptz).';
comment on column public.plan_items.reminder_enabled is 'If true, app may schedule a local notification at scheduled_start_at.';
