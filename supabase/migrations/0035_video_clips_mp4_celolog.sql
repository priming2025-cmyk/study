-- 2초 MP4 클립 메타·셀로그·만료 정리 RPC

alter table public.study_room_video_clips
  add column if not exists mime_type text not null default 'video/mp4',
  add column if not exists duration_ms int,
  add column if not exists size_bytes bigint,
  add column if not exists poster_url text;

create index if not exists study_room_video_clips_expires_idx
  on public.study_room_video_clips (expires_at);

-- 만료된 클립 목록 (Edge Function / cron에서 storage 삭제용)
create or replace function public.list_expired_study_room_video_clips(p_limit int default 500)
returns table (id uuid, storage_path text)
language sql
stable
security definer
set search_path = public
as $$
  select c.id, c.storage_path
  from public.study_room_video_clips c
  where c.expires_at < now()
  order by c.expires_at asc
  limit greatest(1, least(p_limit, 2000));
$$;

grant execute on function public.list_expired_study_room_video_clips(int) to service_role;

-- 만료 행 삭제 (storage는 Edge Function이 먼저 비움)
create or replace function public.delete_study_room_video_clip_rows(p_ids uuid[])
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  delete from public.study_room_video_clips
  where id = any (p_ids);
  get diagnostics n = row_count;
  return n;
end;
$$;

grant execute on function public.delete_study_room_video_clip_rows(uuid[]) to service_role;

-- 오늘 내 클립 (셀로그)
create or replace function public.my_study_room_video_clips_today(p_room_id uuid default null)
returns setof public.study_room_video_clips
language sql
stable
security definer
set search_path = public
as $$
  select c.*
  from public.study_room_video_clips c
  where c.user_id = auth.uid()
    and c.recorded_at >= date_trunc('day', now() at time zone 'utc')
    and (p_room_id is null or c.room_id = p_room_id)
  order by c.recorded_at asc;
$$;

grant execute on function public.my_study_room_video_clips_today(uuid) to authenticated;
