-- Study-up · Realtime 운영 참고 (실행으로 DB 스키마가 바뀌지는 않습니다)
--
-- 1) Flutter 앱의 `study_presence:*`, `study_room:*` 채널은 Supabase Realtime의
--    **Broadcast / Presence** 기능입니다. `supabase_realtime` publication에
--    테이블을 추가하는 것과는 별개입니다.
-- 2) 대시보드에서 Project Settings → API → Realtime 이 켜져 있는지 확인하세요.
-- 3) Postgres Changes(테이블 구독)를 쓸 때만 `alter publication supabase_realtime add table ...`
--    가 필요합니다. 공식 문서의 Realtime 챕터를 따르세요.

select 1;
