-- 친구 DM 답장(스레드) — reply_to_message_id

alter table public.friend_messages
  add column if not exists reply_to_message_id uuid references public.friend_messages(id)
  on delete set null;

create index if not exists friend_messages_reply_idx
  on public.friend_messages (reply_to_message_id, created_at desc);

-- insert RLS는 reply_to_message_id가 동일한 스레드(동일 송/수신 조합)에 속할 때만 허용
-- (기존 policy는 0031에서 생성됨. 여기서는 insert policy를 재정의하기 위해 drop+create)

drop policy if exists "friend_messages_insert" on public.friend_messages;
create policy "friend_messages_insert"
on public.friend_messages for insert
with check (
  sender_id = auth.uid()
  and public._are_friends(sender_id, recipient_id)
  and (
    reply_to_message_id is null
    or exists (
      select 1
      from public.friend_messages r
      where r.id = reply_to_message_id
        and (
          (r.sender_id = sender_id and r.recipient_id = recipient_id)
          or
          (r.sender_id = recipient_id and r.recipient_id = sender_id)
        )
    )
  )
);
