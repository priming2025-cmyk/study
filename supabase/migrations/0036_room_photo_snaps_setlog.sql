-- 1분 사진 히스토리(24h) + 셋로그 타임랩스용 RPC + 만료 정리

create table if not exists public.study_room_photo_snaps (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.study_rooms (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  storage_path text not null,
  public_url text not null,
  recorded_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '1 day'),
  size_bytes bigint
);

create index if not exists study_room_photo_snaps_user_day_idx
  on public.study_room_photo_snaps (user_id, recorded_at desc);

create index if not exists study_room_photo_snaps_expires_idx
  on public.study_room_photo_snaps (expires_at);

alter table public.study_room_photo_snaps enable row level security;

drop policy if exists "study_room_photo_snaps_select_room" on public.study_room_photo_snaps;
create policy "study_room_photo_snaps_select_room"
on public.study_room_photo_snaps for select
using (
  exists (
    select 1 from public.study_room_members m
    where m.room_id = study_room_photo_snaps.room_id
      and m.user_id = auth.uid()
      and m.left_at is null
  )
);

drop policy if exists "study_room_photo_snaps_insert_own" on public.study_room_photo_snaps;
create policy "study_room_photo_snaps_insert_own"
on public.study_room_photo_snaps for insert
with check (user_id = auth.uid());

-- 만료된 사진 목록 (Edge Function / cron에서 storage 삭제용)
create or replace function public.list_expired_study_room_photo_snaps(p_limit int default 500)
returns table (id uuid, storage_path text)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.storage_path
  from public.study_room_photo_snaps p
  where p.expires_at < now()
  order by p.expires_at asc
  limit greatest(1, least(p_limit, 2000));
$$;

grant execute on function public.list_expired_study_room_photo_snaps(int) to service_role;

create or replace function public.delete_study_room_photo_snap_rows(p_ids uuid[])
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  delete from public.study_room_photo_snaps
  where id = any (p_ids);
  get diagnostics n = row_count;
  return n;
end;
$$;

grant execute on function public.delete_study_room_photo_snap_rows(uuid[]) to service_role;

-- 오늘 내 사진 스냅샷(셋로그)
create or replace function public.my_study_room_photo_snaps_today(p_room_id uuid default null)
returns setof public.study_room_photo_snaps
language sql
stable
security definer
set search_path = public
as $$
  select p.*
  from public.study_room_photo_snaps p
  where p.user_id = auth.uid()
    and p.recorded_at >= date_trunc('day', now() at time zone 'utc')
    and (p_room_id is null or p.room_id = p_room_id)
  order by p.recorded_at asc;
$$;

grant execute on function public.my_study_room_photo_snaps_today(uuid) to authenticated;

