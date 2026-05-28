-- 프로필 사진, 셋터디 방 동료 자동 친구, 같은 방 DM 허용, DM 첨부, 2초 영상 클립(24h)

alter table public.profiles
  add column if not exists avatar_url text;

alter table public.friend_messages
  add column if not exists attachment_url text,
  add column if not exists attachment_type text check (
    attachment_type is null or attachment_type in ('image', 'file')
  );

-- 같은 셋터디 방(활성 멤버)이면 친구가 아니어도 DM 가능
create or replace function public._in_same_active_study_room(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.study_room_members m1
    join public.study_room_members m2 on m1.room_id = m2.room_id
    where m1.user_id = a
      and m2.user_id = b
      and m1.left_at is null
      and m2.left_at is null
  );
$$;

drop policy if exists "friend_messages_insert" on public.friend_messages;
create policy "friend_messages_insert"
on public.friend_messages for insert
with check (
  sender_id = auth.uid()
  and (
    public._are_friends(sender_id, recipient_id)
    or public._in_same_active_study_room(sender_id, recipient_id)
  )
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

drop policy if exists "friend_messages_select" on public.friend_messages;
create policy "friend_messages_select"
on public.friend_messages for select
using (
  (sender_id = auth.uid() or recipient_id = auth.uid())
  and (
    public._are_friends(sender_id, recipient_id)
    or public._in_same_active_study_room(sender_id, recipient_id)
  )
);

-- 방 입장 시 동료와 양방향 친구 링크 (셀프)
create or replace function public.ensure_study_room_mates_friends(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  peer uuid;
begin
  if me is null or p_room_id is null then
    return;
  end if;

  for peer in
    select m.user_id
    from public.study_room_members m
    where m.room_id = p_room_id
      and m.left_at is null
      and m.user_id <> me
  loop
    insert into public.friend_links (user_id, peer_id)
    values (me, peer)
    on conflict do nothing;
    insert into public.friend_links (user_id, peer_id)
    values (peer, me)
    on conflict do nothing;
  end loop;
end;
$$;

grant execute on function public.ensure_study_room_mates_friends(uuid) to authenticated;

-- 2초 영상 클립 (24시간 후 삭제 — 앱/크론에서 expires_at 기준 정리)
create table if not exists public.study_room_video_clips (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.study_rooms (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  storage_path text not null,
  public_url text not null,
  recorded_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '1 day')
);

create index if not exists study_room_video_clips_user_day_idx
  on public.study_room_video_clips (user_id, recorded_at desc);

alter table public.study_room_video_clips enable row level security;

drop policy if exists "study_room_video_clips_select_room" on public.study_room_video_clips;
create policy "study_room_video_clips_select_room"
on public.study_room_video_clips for select
using (
  exists (
    select 1 from public.study_room_members m
    where m.room_id = study_room_video_clips.room_id
      and m.user_id = auth.uid()
      and m.left_at is null
  )
);

drop policy if exists "study_room_video_clips_insert_own" on public.study_room_video_clips;
create policy "study_room_video_clips_insert_own"
on public.study_room_video_clips for insert
with check (user_id = auth.uid());
