-- 0041: 셋로그 사진 — KST(Asia/Seoul) 자정 기준 '오늘' + 만료 정리

create or replace function public.study_room_photo_snaps_room_today(p_room_id uuid)
returns setof public.study_room_photo_snaps
language sql
stable
security definer
set search_path = public
as $$
  select p.*
  from public.study_room_photo_snaps p
  where p.room_id = p_room_id
    and p.recorded_at >= date_trunc('day', now() at time zone 'Asia/Seoul')
    and p.recorded_at < date_trunc('day', now() at time zone 'Asia/Seoul') + interval '1 day'
    and p.expires_at > now()
    and exists (
      select 1
      from public.study_room_members m
      where m.room_id = p_room_id
        and m.user_id = auth.uid()
        and m.left_at is null
    )
  order by p.recorded_at asc;
$$;

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
    and (p_room_id is null or p.room_id = p_room_id)
    and p.recorded_at >= date_trunc('day', now() at time zone 'Asia/Seoul')
    and p.recorded_at < date_trunc('day', now() at time zone 'Asia/Seoul') + interval '1 day'
    and p.expires_at > now()
  order by p.recorded_at asc;
$$;

-- 자정 이후 만료된 행·Storage 정리용 (Edge Function / cron)
create or replace function public.list_expired_study_room_photo_snaps(p_limit int default 500)
returns table (id uuid, storage_path text)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.storage_path
  from public.study_room_photo_snaps p
  where p.expires_at <= now()
     or p.recorded_at < date_trunc('day', now() at time zone 'Asia/Seoul')
  order by p.recorded_at asc
  limit greatest(1, least(p_limit, 2000));
$$;
