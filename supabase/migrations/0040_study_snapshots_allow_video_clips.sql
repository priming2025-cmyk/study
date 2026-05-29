-- study-snapshots: 2초 영상(MP4/WebM)·셋로그 JPEG 업로드 허용
-- 기존 100KB·image/jpeg|png 만 허용 → video 업로드가 Storage에서 거절되어
-- presence에 latest_clip_url이 비어 캠코더 플레이스홀더만 보이던 문제 수정

update storage.buckets
set
  file_size_limit = 2097152,
  allowed_mime_types = array[
    'image/jpeg',
    'image/png',
    'video/mp4',
    'video/webm'
  ]::text[]
where id = 'study-snapshots';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'study-snapshots',
  'study-snapshots',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'video/mp4', 'video/webm']::text[]
)
on conflict (id) do update
set
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
