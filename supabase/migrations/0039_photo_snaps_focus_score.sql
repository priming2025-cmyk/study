-- 0039: photo snaps에 집중도(focus_score) 저장
-- - 셀로그 영상에서 "집중도"를 더 정확하게 보여주기 위함

alter table public.study_room_photo_snaps
  add column if not exists focus_score int;

