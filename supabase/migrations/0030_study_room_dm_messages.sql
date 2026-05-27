-- 셋터디 방 안 1:1 DM (recipient_user_id)
alter table public.study_room_messages
  add column if not exists recipient_user_id uuid references public.profiles(id) on delete cascade;

create index if not exists study_room_messages_dm_idx
  on public.study_room_messages (room_id, recipient_user_id, user_id, created_at desc);

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
  and (
    recipient_user_id is null
    or user_id = auth.uid()
    or recipient_user_id = auth.uid()
  )
);

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
  and (
    recipient_user_id is null
    or exists (
      select 1 from public.study_room_members r
      where r.room_id = study_room_messages.room_id
        and r.user_id = recipient_user_id
        and r.left_at is null
    )
  )
);
