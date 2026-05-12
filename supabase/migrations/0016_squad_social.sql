-- Squads + friend requests + squad week contribution + leaderboard RPCs

create table if not exists public.squads (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  mission_target_seconds integer not null default 180000 check (mission_target_seconds > 0),
  created_at timestamptz not null default now()
);

create table if not exists public.squad_members (
  squad_id uuid not null references public.squads (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (squad_id, user_id)
);

create index if not exists squad_members_user_active_idx
  on public.squad_members (user_id)
  where left_at is null;

create table if not exists public.squad_week_contributions (
  squad_id uuid not null references public.squads (id) on delete cascade,
  week_start date not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  focused_seconds integer not null default 0 check (focused_seconds >= 0),
  primary key (squad_id, week_start, user_id)
);

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references public.profiles (id) on delete cascade,
  to_user_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  unique (from_user_id, to_user_id),
  check (from_user_id <> to_user_id)
);

create table if not exists public.friend_links (
  user_id uuid not null references public.profiles (id) on delete cascade,
  peer_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, peer_id),
  check (user_id <> peer_id)
);

alter table public.squads enable row level security;
alter table public.squad_members enable row level security;
alter table public.squad_week_contributions enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friend_links enable row level security;

drop policy if exists "squads_select_member" on public.squads;
create policy "squads_select_member"
on public.squads for select
using (
  exists (
    select 1 from public.squad_members m
    where m.squad_id = squads.id and m.user_id = auth.uid() and m.left_at is null
  )
  or owner_id = auth.uid()
);

drop policy if exists "squads_insert_owner" on public.squads;
create policy "squads_insert_owner"
on public.squads for insert
with check (owner_id = auth.uid());

drop policy if exists "squad_members_select_squad" on public.squad_members;
create policy "squad_members_select_squad"
on public.squad_members for select
using (
  exists (
    select 1 from public.squad_members m2
    where m2.squad_id = squad_members.squad_id and m2.user_id = auth.uid() and m2.left_at is null
  )
);

drop policy if exists "squad_members_insert_self" on public.squad_members;
create policy "squad_members_insert_self"
on public.squad_members for insert
with check (
  user_id = auth.uid()
  or exists (
    select 1 from public.squads s
    where s.id = squad_members.squad_id and s.owner_id = auth.uid()
  )
);

drop policy if exists "squad_members_update_self_leave" on public.squad_members;
create policy "squad_members_update_self_leave"
on public.squad_members for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "squad_week_select_member" on public.squad_week_contributions;
create policy "squad_week_select_member"
on public.squad_week_contributions for select
using (
  exists (
    select 1 from public.squad_members m
    where m.squad_id = squad_week_contributions.squad_id and m.user_id = auth.uid() and m.left_at is null
  )
);

drop policy if exists "friend_requests_select_involved" on public.friend_requests;
create policy "friend_requests_select_involved"
on public.friend_requests for select
using (from_user_id = auth.uid() or to_user_id = auth.uid());

drop policy if exists "friend_requests_insert_from" on public.friend_requests;
create policy "friend_requests_insert_from"
on public.friend_requests for insert
with check (from_user_id = auth.uid());

drop policy if exists "friend_requests_update_to" on public.friend_requests;
create policy "friend_requests_update_to"
on public.friend_requests for update
using (to_user_id = auth.uid());

drop policy if exists "friend_links_select_own" on public.friend_links;
create policy "friend_links_select_own"
on public.friend_links for select
using (user_id = auth.uid());

create or replace function public._week_start_utc(d timestamptz)
returns date
language sql
immutable
as $$
  select (date_trunc('week', timezone('utc', d)))::date;
$$;

create table if not exists public.squad_session_grants (
  session_id uuid primary key references public.study_sessions (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  squad_id uuid not null references public.squads (id) on delete cascade,
  week_start date not null,
  focused_seconds integer not null check (focused_seconds > 0)
);

alter table public.squad_session_grants enable row level security;

drop policy if exists "squad_session_grants_select_member" on public.squad_session_grants;
create policy "squad_session_grants_select_member"
on public.squad_session_grants for select
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.squad_members m
    where m.squad_id = squad_session_grants.squad_id and m.user_id = auth.uid() and m.left_at is null
  )
);

create or replace function public.apply_squad_session_contribution(
  p_session_id uuid,
  p_focused_seconds integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_squad uuid;
  v_week date;
  v_new uuid;
begin
  if v_uid is null or p_focused_seconds is null or p_focused_seconds <= 0 then
    return;
  end if;

  select squad_id into v_squad
  from public.squad_members
  where user_id = v_uid and left_at is null
  limit 1;

  if v_squad is null then
    return;
  end if;

  v_week := public._week_start_utc(now());

  insert into public.squad_session_grants (session_id, user_id, squad_id, week_start, focused_seconds)
  values (p_session_id, v_uid, v_squad, v_week, p_focused_seconds)
  on conflict (session_id) do nothing
  returning session_id into v_new;

  if v_new is null then
    return;
  end if;

  insert into public.squad_week_contributions (squad_id, week_start, user_id, focused_seconds)
  values (v_squad, v_week, v_uid, p_focused_seconds)
  on conflict (squad_id, week_start, user_id)
  do update set focused_seconds = public.squad_week_contributions.focused_seconds + excluded.focused_seconds;
end;
$$;

revoke all on function public.apply_squad_session_contribution(uuid, integer) from public;
grant execute on function public.apply_squad_session_contribution(uuid, integer) to authenticated;

create or replace function public.accept_friend_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  select * into r from public.friend_requests where id = p_request_id and to_user_id = auth.uid() for update;
  if not found then
    raise exception 'not_found';
  end if;
  if r.status <> 'pending' then
    return;
  end if;

  update public.friend_requests set status = 'accepted' where id = p_request_id;

  insert into public.friend_links (user_id, peer_id) values (r.from_user_id, r.to_user_id)
  on conflict do nothing;
  insert into public.friend_links (user_id, peer_id) values (r.to_user_id, r.from_user_id)
  on conflict do nothing;
end;
$$;

revoke all on function public.accept_friend_request(uuid) from public;
grant execute on function public.accept_friend_request(uuid) to authenticated;

create or replace function public.friend_week_rankings()
returns table (peer_id uuid, display_name text, focused_seconds bigint, rank bigint)
language sql
security definer
set search_path = public
as $$
  with week_bounds as (
    select
      (date_trunc('week', timezone('utc', now())))::timestamptz as start_utc,
      (date_trunc('week', timezone('utc', now())) + interval '7 day')::timestamptz as end_utc
  ),
  peers as (
    select fl.peer_id
    from public.friend_links fl
    where fl.user_id = auth.uid()
  ),
  agg as (
    select s.user_id as uid, sum(s.focused_seconds)::bigint as sec
    from public.study_sessions s
    cross join week_bounds b
    where s.user_id in (select peer_id from peers)
      and s.started_at >= b.start_utc
      and s.started_at < b.end_utc
    group by s.user_id
  )
  select
    p.id as peer_id,
    coalesce(p.display_name, '친구') as display_name,
    coalesce(a.sec, 0::bigint) as focused_seconds,
    rank() over (order by coalesce(a.sec, 0) desc) as rank
  from peers pr
  join public.profiles p on p.id = pr.peer_id
  left join agg a on a.uid = p.id
  order by coalesce(a.sec, 0) desc;
$$;

revoke all on function public.friend_week_rankings() from public;
grant execute on function public.friend_week_rankings() to authenticated;

create or replace function public.squad_week_progress(p_squad_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_week date := public._week_start_utc(now());
  v_target integer;
  v_sum bigint;
begin
  if not exists (
    select 1 from public.squad_members m
    where m.squad_id = p_squad_id and m.user_id = auth.uid() and m.left_at is null
  ) then
    raise exception 'forbidden';
  end if;

  select mission_target_seconds into v_target from public.squads where id = p_squad_id;

  select coalesce(sum(focused_seconds), 0)::bigint into v_sum
  from public.squad_week_contributions
  where squad_id = p_squad_id and week_start = v_week;

  return jsonb_build_object(
    'week_start', v_week,
    'mission_target_seconds', v_target,
    'team_focused_seconds', v_sum,
    'ratio', case when v_target <= 0 then 0 else least(1.0, v_sum::float / v_target::float) end
  );
end;
$$;

revoke all on function public.squad_week_progress(uuid) from public;
grant execute on function public.squad_week_progress(uuid) to authenticated;

create or replace function public.list_friends()
returns table (peer_id uuid, display_name text, level integer)
language sql
security definer
set search_path = public
as $$
  select p.id, coalesce(p.display_name, '친구') as display_name, p.level
  from public.friend_links fl
  join public.profiles p on p.id = fl.peer_id
  where fl.user_id = auth.uid();
$$;

revoke all on function public.list_friends() from public;
grant execute on function public.list_friends() to authenticated;
