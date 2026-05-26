-- Repeat series for plan items (exact series delete/update)
-- Adds `plan_repeat_series` and `plan_items.repeat_series_id`.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Repeat series master
-- ---------------------------------------------------------------------------
create table if not exists public.plan_repeat_series (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,

  -- recurrence rule
  unit text not null default 'week' check (unit in ('day', 'week')),
  interval integer not null default 1 check (interval >= 1 and interval <= 52),
  weekdays smallint[] not null default '{1}'::smallint[],

  -- period (inclusive)
  start_date date not null,
  end_date date not null,

  -- optional planned start time within a day (minutes since 00:00, nullable)
  start_time_minutes smallint,
  reminder_enabled boolean not null default false,

  -- content
  subject text not null,
  target_seconds integer not null check (target_seconds >= 0),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  check (end_date >= start_date),
  check (start_time_minutes is null or (start_time_minutes >= 0 and start_time_minutes < 1440))
);

create index if not exists plan_repeat_series_user_idx
on public.plan_repeat_series (user_id, start_date, end_date);

drop trigger if exists plan_repeat_series_set_updated_at on public.plan_repeat_series;
create trigger plan_repeat_series_set_updated_at
before update on public.plan_repeat_series
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Link occurrences to series
-- ---------------------------------------------------------------------------
alter table public.plan_items
  add column if not exists repeat_series_id uuid references public.plan_repeat_series (id) on delete cascade;

create index if not exists plan_items_repeat_series_idx
on public.plan_items (repeat_series_id);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.plan_repeat_series enable row level security;

drop policy if exists "plan_repeat_series_owner_crud" on public.plan_repeat_series;
create policy "plan_repeat_series_owner_crud"
on public.plan_repeat_series
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

