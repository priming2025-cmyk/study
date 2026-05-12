create table if not exists public.study_room_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.study_rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

alter table public.study_room_messages enable row level security;

-- 방에 참여 중인 멤버만 읽기 가능
drop policy if exists "study_room_messages_select" on public.study_room_messages;
create policy "study_room_messages_select"
on public.study_room_messages for select
using (
  exists (
    select 1 from public.study_room_members m
    where m.room_id = study_room_messages.room_id
      and m.user_id = auth.uid()
      and m.left_at is null
  )
);

-- 본인이 참여 중인 방에만 쓰기 가능
drop policy if exists "study_room_messages_insert" on public.study_room_messages;
create policy "study_room_messages_insert"
on public.study_room_messages for insert
with check (
  auth.uid() = user_id
  and exists (
    select 1 from public.study_room_members m
    where m.room_id = study_room_messages.room_id
      and m.user_id = auth.uid()
      and m.left_at is null
  )
);

-- Realtime: supabase_realtime publication에 추가 (PL/pgSQL DO 로만 IF 사용 가능)
do $migration$
begin
  if not exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'study_room_messages'
  ) then
    alter publication supabase_realtime add table public.study_room_messages;
  end if;
end
$migration$;
