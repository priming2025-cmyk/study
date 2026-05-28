-- user-media Storage bucket
-- 목적:
-- - 프로필 아바타 (avatars/)
-- - 친구 DM 첨부(사진/파일) (dm/)
-- 기존 study-snapshots 버킷은 100KB 제한이라 아바타/첨부 업로드가 StorageException으로 실패할 수 있습니다.

-- 1) 버킷 생성 (이미 있으면 무시)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'user-media',
  'user-media',
  true,
  5242880, -- 5 MB
  array[
    'image/jpeg',
    'image/png',
    'image/webp'
  ]
)
on conflict (id) do nothing;

-- 2) 공개 읽기
drop policy if exists "user_media_public_read" on storage.objects;
create policy "user_media_public_read"
on storage.objects for select
using (bucket_id = 'user-media');

-- 3) 인증 사용자: 업로드 허용
drop policy if exists "user_media_insert_authenticated" on storage.objects;
create policy "user_media_insert_authenticated"
on storage.objects for insert
with check (
  bucket_id = 'user-media'
  and auth.role() = 'authenticated'
);

-- 4) 본인 업로드만 수정/삭제 허용
drop policy if exists "user_media_update_self" on storage.objects;
create policy "user_media_update_self"
on storage.objects for update
using (
  bucket_id = 'user-media'
  and owner = auth.uid()
);

drop policy if exists "user_media_delete_self" on storage.objects;
create policy "user_media_delete_self"
on storage.objects for delete
using (
  bucket_id = 'user-media'
  and owner = auth.uid()
);

