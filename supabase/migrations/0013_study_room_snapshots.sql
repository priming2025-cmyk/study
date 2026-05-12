-- study-snapshots Storage bucket
-- 각 멤버가 60초마다 저해상도 JPEG를 업로드합니다.
-- 경로: {roomId}/{userId}.jpg  (같은 파일을 덮어씁니다)
-- WebRTC 실시간 영상 없이 서로 공부 중임을 확인하는 용도입니다.

-- 1) 버킷 생성 (이미 있으면 무시)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'study-snapshots',
  'study-snapshots',
  true,
  102400,           -- 100 KB 제한 (저화질 JPEG)
  array['image/jpeg', 'image/png']
)
on conflict (id) do nothing;

-- 2) RLS 활성화는 storage.objects 테이블에서 자동 관리됩니다.
--    아래 정책만 추가합니다.

-- 공개 읽기 (방 ID + 사용자 ID를 알면 누구나 볼 수 있음)
drop policy if exists "study_snapshots_public_read" on storage.objects;
create policy "study_snapshots_public_read"
on storage.objects for select
using (bucket_id = 'study-snapshots');

-- 인증 사용자: 본인 파일 업로드 허용
drop policy if exists "study_snapshots_insert_self" on storage.objects;
create policy "study_snapshots_insert_self"
on storage.objects for insert
with check (
  bucket_id = 'study-snapshots'
  and auth.role() = 'authenticated'
);

-- 인증 사용자: 본인이 올린 파일만 수정 허용 (owner 컬럼 = 업로드한 uid)
drop policy if exists "study_snapshots_update_self" on storage.objects;
create policy "study_snapshots_update_self"
on storage.objects for update
using (
  bucket_id = 'study-snapshots'
  and owner = auth.uid()
);

drop policy if exists "study_snapshots_delete_self" on storage.objects;
create policy "study_snapshots_delete_self"
on storage.objects for delete
using (
  bucket_id = 'study-snapshots'
  and owner = auth.uid()
);
