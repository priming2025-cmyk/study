-- 짧은 입장코드 (6자) + 최대 8명
alter table public.study_rooms
  add column if not exists join_code text;

create unique index if not exists study_rooms_join_code_unique
  on public.study_rooms (upper(join_code))
  where join_code is not null;

-- max_peers 8명까지 (앱과 동기화)
alter table public.study_rooms drop constraint if exists study_rooms_max_peers_check;
alter table public.study_rooms
  add constraint study_rooms_max_peers_check
  check (max_peers between 2 and 8);
