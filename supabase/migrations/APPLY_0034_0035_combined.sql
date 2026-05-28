-- Supabase Dashboard → SQL Editor → Run once
-- (CLI db:push 권한 없을 때 이 파일 전체 붙여넣기)

-- ========== 0034 ==========
alter table public.profiles
  add column if not exists avatar_url text;

alter table public.friend_messages
  add column if not exists attachment_url text,
  add column if not exists attachment_type text check (
    attachment_type is null or attachment_type in ('image', 'file')
  );

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

-- ========== 0035 ==========
alter table public.study_room_video_clips
  add column if not exists mime_type text not null default 'video/mp4',
  add column if not exists duration_ms int,
  add column if not exists size_bytes bigint,
  add column if not exists poster_url text;

create index if not exists study_room_video_clips_expires_idx
  on public.study_room_video_clips (expires_at);

create or replace function public.list_expired_study_room_video_clips(p_limit int default 500)
returns table (id uuid, storage_path text)
language sql
stable
security definer
set search_path = public
as $$
  select c.id, c.storage_path
  from public.study_room_video_clips c
  where c.expires_at < now()
  order by c.expires_at asc
  limit greatest(1, least(p_limit, 2000));
$$;

grant execute on function public.list_expired_study_room_video_clips(int) to service_role;

create or replace function public.delete_study_room_video_clip_rows(p_ids uuid[])
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  delete from public.study_room_video_clips
  where id = any (p_ids);
  get diagnostics n = row_count;
  return n;
end;
$$;

grant execute on function public.delete_study_room_video_clip_rows(uuid[]) to service_role;

create or replace function public.my_study_room_video_clips_today(p_room_id uuid default null)
returns setof public.study_room_video_clips
language sql
stable
security definer
set search_path = public
as $$
  select c.*
  from public.study_room_video_clips c
  where c.user_id = auth.uid()
    and c.recorded_at >= date_trunc('day', now() at time zone 'utc')
    and (p_room_id is null or c.room_id = p_room_id)
  order by c.recorded_at asc;
$$;

grant execute on function public.my_study_room_video_clips_today(uuid) to authenticated;
