-- 0038: 멀티멤버 셀로그 — 사진 상태텍스트 + 방 전체 조회 RPC
--
-- 1) study_room_photo_snaps 에 status_text 컬럼 추가
--    (사진 찍을 때의 공부 상태를 같이 저장 → 셀로그 영상에 오버레이)
alter table public.study_room_photo_snaps
  add column if not exists status_text text;

-- 2) RPC: 방 전체 멤버의 오늘 사진 스냅 조회
--    호출자가 해당 방의 현재 멤버인 경우에만 반환
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
    and p.recorded_at >= date_trunc('day', now() at time zone 'utc')
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

grant execute on function public.study_room_photo_snaps_room_today(uuid)
  to authenticated;

-- 3) RPC: 방 전체 멤버의 오늘 2초 영상 클립 조회
create or replace function public.study_room_video_clips_room_today(p_room_id uuid)
returns setof public.study_room_video_clips
language sql
stable
security definer
set search_path = public
as $$
  select c.*
  from public.study_room_video_clips c
  where c.room_id = p_room_id
    and c.recorded_at >= date_trunc('day', now() at time zone 'utc')
    and c.expires_at > now()
    and exists (
      select 1
      from public.study_room_members m
      where m.room_id = p_room_id
        and m.user_id = auth.uid()
        and m.left_at is null
    )
  order by c.recorded_at asc;
$$;

grant execute on function public.study_room_video_clips_room_today(uuid)
  to authenticated;
