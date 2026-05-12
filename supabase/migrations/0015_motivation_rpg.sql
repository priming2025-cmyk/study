-- RPG: titles, XP/level on profiles, XP ledger, apply_session_progress RPC
-- Streak fields for retention / "잔디" input

create table if not exists public.titles (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name_ko text not null,
  min_level integer not null default 1 check (min_level >= 1),
  sort_order integer not null default 0
);

insert into public.titles (slug, name_ko, min_level, sort_order) values
  ('seed', '새싹 러너', 1, 10),
  ('sprout', '싹튼 집중러', 3, 20),
  ('steady', '꾸준한 독서가', 6, 30),
  ('spark', '불꽃 도전자', 10, 40),
  ('star', '별빛 마스터', 15, 50)
on conflict (slug) do nothing;

alter table public.profiles
  add column if not exists xp_total integer not null default 0 check (xp_total >= 0),
  add column if not exists level integer not null default 1 check (level >= 1),
  add column if not exists equipped_title_id uuid references public.titles (id) on delete set null,
  add column if not exists streak_current integer not null default 0 check (streak_current >= 0),
  add column if not exists streak_best integer not null default 0 check (streak_best >= 0),
  add column if not exists streak_last_activity_date date,
  add column if not exists equipped_border_key text;

create index if not exists profiles_level_idx on public.profiles (level desc);

create table if not exists public.user_titles (
  user_id uuid not null references public.profiles (id) on delete cascade,
  title_id uuid not null references public.titles (id) on delete cascade,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, title_id)
);

create index if not exists user_titles_user_idx on public.user_titles (user_id);

create table if not exists public.xp_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  session_id uuid references public.study_sessions (id) on delete set null,
  xp integer not null check (xp > 0),
  created_at timestamptz not null default now(),
  unique (user_id, session_id)
);

create index if not exists xp_events_user_idx on public.xp_events (user_id, created_at desc);

alter table public.titles enable row level security;
alter table public.user_titles enable row level security;
alter table public.xp_events enable row level security;

drop policy if exists "titles_select_all" on public.titles;
create policy "titles_select_all"
on public.titles for select
to authenticated
using (true);

drop policy if exists "user_titles_select_own" on public.user_titles;
create policy "user_titles_select_own"
on public.user_titles for select
using (user_id = auth.uid());

drop policy if exists "xp_events_select_own" on public.xp_events;
create policy "xp_events_select_own"
on public.xp_events for select
using (user_id = auth.uid());

create or replace function public._level_from_xp(p_xp bigint)
returns integer
language sql
immutable
as $$
  select greatest(1, (p_xp / 400)::int + 1);
$$;

create or replace function public._sync_unlocked_titles(p_user_id uuid, p_level integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_titles (user_id, title_id)
  select p_user_id, t.id
  from public.titles t
  where t.min_level <= p_level
  on conflict (user_id, title_id) do nothing;
end;
$$;

create or replace function public._bump_streak(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := (timezone('utc', now()))::date;
  v_last date;
  v_cur integer;
  v_best integer;
begin
  select streak_last_activity_date, streak_current, streak_best
    into v_last, v_cur, v_best
  from public.profiles where id = p_user_id for update;

  if v_last is null then
    update public.profiles
      set streak_current = 1,
          streak_best = greatest(1, streak_best),
          streak_last_activity_date = v_today
      where id = p_user_id;
    return;
  end if;

  if v_last = v_today then
    return;
  end if;

  if v_last = v_today - 1 then
    v_cur := coalesce(v_cur, 0) + 1;
  else
    v_cur := 1;
  end if;

  v_best := greatest(coalesce(v_best, 0), v_cur);

  update public.profiles
    set streak_current = v_cur,
        streak_best = v_best,
        streak_last_activity_date = v_today
    where id = p_user_id;
end;
$$;

create or replace function public.apply_session_progress(
  p_user_id uuid,
  p_session_id uuid,
  p_focused_seconds integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_xp integer;
  v_inserted_xp integer;
  v_new_total bigint;
  v_new_level integer;
begin
  if p_user_id is distinct from auth.uid() then
    raise exception 'forbidden';
  end if;

  if p_focused_seconds is null or p_focused_seconds <= 0 then
    return jsonb_build_object('xp', 0, 'level', (select level from public.profiles where id = p_user_id));
  end if;

  v_xp := least(400, greatest(1, p_focused_seconds / 60));

  insert into public.xp_events (user_id, session_id, xp)
  values (p_user_id, p_session_id, v_xp)
  on conflict (user_id, session_id) do nothing
  returning xp into v_inserted_xp;

  if v_inserted_xp is null then
    return jsonb_build_object(
      'xp', 0,
      'level', (select level from public.profiles where id = p_user_id),
      'duplicate', true
    );
  end if;

  update public.profiles
    set xp_total = xp_total + v_xp
    where id = p_user_id
    returning xp_total into v_new_total;

  v_new_level := public._level_from_xp(v_new_total);

  update public.profiles
    set level = v_new_level
    where id = p_user_id;

  perform public._sync_unlocked_titles(p_user_id, v_new_level);
  perform public._bump_streak(p_user_id);

  return jsonb_build_object(
    'xp', v_xp,
    'xp_total', v_new_total,
    'level', v_new_level,
    'titles_unlocked', (select count(*)::int from public.user_titles where user_id = p_user_id)
  );
end;
$$;

revoke all on function public.apply_session_progress(uuid, uuid, integer) from public;
grant execute on function public.apply_session_progress(uuid, uuid, integer) to authenticated;

create or replace function public.equip_title(p_title_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not exists (
    select 1 from public.user_titles where user_id = auth.uid() and title_id = p_title_id
  ) then
    raise exception 'title_not_owned';
  end if;
  update public.profiles
    set equipped_title_id = p_title_id
    where id = auth.uid();
end;
$$;

revoke all on function public.equip_title(uuid) from public;
grant execute on function public.equip_title(uuid) to authenticated;
