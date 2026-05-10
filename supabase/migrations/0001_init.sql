-- Study-up MVP schema (Supabase Postgres)
-- Principle: store ONLY session summaries; never store camera frames/face embeddings.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.user_role as enum ('student', 'parent', 'teacher', 'admin');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type public.session_validation_state as enum ('OK', 'UNCERTAIN', 'FAILED');
exception
  when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- Profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null default 'student',
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_role_idx on public.profiles (role);

-- updated_at trigger
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Parent <-> Student link (parent can view child summaries)
-- ---------------------------------------------------------------------------
create table if not exists public.parent_links (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid not null references public.profiles (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (parent_id, student_id),
  check (parent_id <> student_id)
);

create index if not exists parent_links_parent_idx on public.parent_links (parent_id);
create index if not exists parent_links_student_idx on public.parent_links (student_id);

-- ---------------------------------------------------------------------------
-- Daily plans (simple MVP)
-- ---------------------------------------------------------------------------
create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  plan_date date not null,
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, plan_date)
);

drop trigger if exists plans_set_updated_at on public.plans;
create trigger plans_set_updated_at
before update on public.plans
for each row execute function public.set_updated_at();

create table if not exists public.plan_items (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans (id) on delete cascade,
  subject text not null,
  target_seconds integer not null check (target_seconds >= 0),
  priority smallint not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists plan_items_plan_idx on public.plan_items (plan_id);

-- ---------------------------------------------------------------------------
-- Study sessions (summaries only)
-- ---------------------------------------------------------------------------
create table if not exists public.study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz,
  focused_seconds integer not null default 0 check (focused_seconds >= 0),
  unfocused_seconds integer not null default 0 check (unfocused_seconds >= 0),
  validation_state public.session_validation_state not null default 'UNCERTAIN',
  pause_count integer not null default 0 check (pause_count >= 0),
  app_background_count integer not null default 0 check (app_background_count >= 0),
  face_missing_events integer not null default 0 check (face_missing_events >= 0),
  multi_face_events integer not null default 0 check (multi_face_events >= 0),
  device_tz text,
  created_at timestamptz not null default now()
);

create index if not exists study_sessions_user_started_idx on public.study_sessions (user_id, started_at desc);

-- ---------------------------------------------------------------------------
-- Study rooms (metadata only; media is P2P)
-- ---------------------------------------------------------------------------
create table if not exists public.study_rooms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  max_peers smallint not null default 4 check (max_peers between 2 and 4),
  created_at timestamptz not null default now()
);

create table if not exists public.study_room_members (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.study_rooms (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  unique (room_id, user_id)
);

create index if not exists study_room_members_room_idx on public.study_room_members (room_id);
create index if not exists study_room_members_user_idx on public.study_room_members (user_id);

-- ---------------------------------------------------------------------------
-- Audit logs (parent view actions)
-- ---------------------------------------------------------------------------
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles (id) on delete cascade,
  action text not null,
  target_user_id uuid references public.profiles (id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_logs_actor_idx on public.audit_logs (actor_id, created_at desc);
create index if not exists audit_logs_target_idx on public.audit_logs (target_user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.parent_links enable row level security;
alter table public.plans enable row level security;
alter table public.plan_items enable row level security;
alter table public.study_sessions enable row level security;
alter table public.study_rooms enable row level security;
alter table public.study_room_members enable row level security;
alter table public.audit_logs enable row level security;

-- Profiles: user can read/update self
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles for select
using (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles for update
using (id = auth.uid())
with check (id = auth.uid());

-- Parent links:
-- - parent can create link (later we can require student approval)
-- - parent can read their links; student can read links pointing to them
drop policy if exists "parent_links_select_related" on public.parent_links;
create policy "parent_links_select_related"
on public.parent_links for select
using (parent_id = auth.uid() or student_id = auth.uid());

drop policy if exists "parent_links_insert_parent" on public.parent_links;
create policy "parent_links_insert_parent"
on public.parent_links for insert
with check (parent_id = auth.uid());

drop policy if exists "parent_links_delete_parent" on public.parent_links;
create policy "parent_links_delete_parent"
on public.parent_links for delete
using (parent_id = auth.uid());

-- Plans: owner CRUD
drop policy if exists "plans_owner_crud" on public.plans;
create policy "plans_owner_crud"
on public.plans
for all
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- Plan items: access via owning plan
drop policy if exists "plan_items_owner_crud" on public.plan_items;
create policy "plan_items_owner_crud"
on public.plan_items
for all
using (
  exists (
    select 1 from public.plans p
    where p.id = plan_items.plan_id and p.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.plans p
    where p.id = plan_items.plan_id and p.user_id = auth.uid()
  )
);

-- Study sessions:
-- - owner can CRUD
-- - parent can read child's sessions if linked
drop policy if exists "study_sessions_owner_crud" on public.study_sessions;
create policy "study_sessions_owner_crud"
on public.study_sessions
for all
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "study_sessions_parent_read" on public.study_sessions;
create policy "study_sessions_parent_read"
on public.study_sessions
for select
using (
  exists (
    select 1 from public.parent_links l
    where l.parent_id = auth.uid()
      and l.student_id = study_sessions.user_id
  )
);

-- Rooms:
-- - authenticated users can create rooms
-- - members can read room metadata
drop policy if exists "study_rooms_insert_owner" on public.study_rooms;
create policy "study_rooms_insert_owner"
on public.study_rooms for insert
with check (owner_id = auth.uid());

drop policy if exists "study_rooms_select_members" on public.study_rooms;
create policy "study_rooms_select_members"
on public.study_rooms for select
using (
  owner_id = auth.uid()
  or exists (
    select 1 from public.study_room_members m
    where m.room_id = study_rooms.id and m.user_id = auth.uid() and m.left_at is null
  )
);

drop policy if exists "study_rooms_update_owner" on public.study_rooms;
create policy "study_rooms_update_owner"
on public.study_rooms for update
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists "study_rooms_delete_owner" on public.study_rooms;
create policy "study_rooms_delete_owner"
on public.study_rooms for delete
using (owner_id = auth.uid());

-- Room members: user can join/leave themselves; owner can read members
drop policy if exists "study_room_members_select_member_or_owner" on public.study_room_members;
create policy "study_room_members_select_member_or_owner"
on public.study_room_members for select
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.study_rooms r
    where r.id = study_room_members.room_id and r.owner_id = auth.uid()
  )
);

drop policy if exists "study_room_members_insert_self" on public.study_room_members;
create policy "study_room_members_insert_self"
on public.study_room_members for insert
with check (user_id = auth.uid());

drop policy if exists "study_room_members_update_self" on public.study_room_members;
create policy "study_room_members_update_self"
on public.study_room_members for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- Audit logs:
-- - actor can insert for self
-- - actor can read own logs
drop policy if exists "audit_logs_insert_self" on public.audit_logs;
create policy "audit_logs_insert_self"
on public.audit_logs for insert
with check (actor_id = auth.uid());

drop policy if exists "audit_logs_select_own" on public.audit_logs;
create policy "audit_logs_select_own"
on public.audit_logs for select
using (actor_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Helper view: parent can read child's daily summary (optional in MVP)
-- ---------------------------------------------------------------------------
create or replace view public.v_daily_session_summary as
select
  user_id,
  (started_at at time zone 'UTC')::date as day_utc,
  sum(focused_seconds) as focused_seconds,
  sum(unfocused_seconds) as unfocused_seconds,
  sum(pause_count) as pause_count,
  sum(app_background_count) as app_background_count
from public.study_sessions
where ended_at is not null
group by user_id, (started_at at time zone 'UTC')::date;

