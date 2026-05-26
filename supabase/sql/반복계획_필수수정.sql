-- =============================================================================
-- Study-up: 반복 계획(plan_repeat_series) 패치
-- Supabase SQL Editor에서 실행 (한 번만).
-- =============================================================================

create extension if not exists "pgcrypto";

create table if not exists public.plan_repeat_series (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  unit text not null default 'week' check (unit in ('day', 'week')),
  repeat_interval integer not null default 1 check (repeat_interval >= 1 and repeat_interval <= 52),
  weekdays smallint[] not null default '{1}'::smallint[],
  start_date date not null,
  end_date date not null,
  start_time_minutes smallint,
  reminder_enabled boolean not null default false,
  subject text not null,
  target_seconds integer not null check (target_seconds >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date),
  check (start_time_minutes is null or (start_time_minutes >= 0 and start_time_minutes < 1440))
);

-- 예전 0025에 interval 컬럼만 있는 경우
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'plan_repeat_series' and column_name = 'interval'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'plan_repeat_series' and column_name = 'repeat_interval'
  ) then
    alter table public.plan_repeat_series rename column interval to repeat_interval;
  end if;
end $$;

alter table public.plan_items
  add column if not exists repeat_series_id uuid references public.plan_repeat_series (id) on delete cascade;

create index if not exists plan_repeat_series_user_idx
  on public.plan_repeat_series (user_id, start_date, end_date);

create index if not exists plan_items_repeat_series_idx
  on public.plan_items (repeat_series_id);

alter table public.plan_repeat_series enable row level security;

drop policy if exists "plan_repeat_series_owner_crud" on public.plan_repeat_series;
create policy "plan_repeat_series_owner_crud"
on public.plan_repeat_series
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- 완료 후: Supabase Table Editor에서 plan_repeat_series 새로고침, 앱 재실행.
