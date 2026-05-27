-- 친구 간 1:1 DM (셋터디 탭 · 인스타 DM형)
create table if not exists public.friend_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles (id) on delete cascade,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  content text not null check (char_length(trim(content)) > 0),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

create index if not exists friend_messages_thread_idx
  on public.friend_messages (sender_id, recipient_id, created_at desc);

create index if not exists friend_messages_recipient_idx
  on public.friend_messages (recipient_id, created_at desc);

create table if not exists public.friend_dm_reads (
  user_id uuid not null references public.profiles (id) on delete cascade,
  peer_id uuid not null references public.profiles (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (user_id, peer_id),
  check (user_id <> peer_id)
);

alter table public.friend_messages enable row level security;
alter table public.friend_dm_reads enable row level security;

-- 친구 관계 확인 헬퍼
create or replace function public._are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.friend_links fl
    where fl.user_id = a and fl.peer_id = b
  );
$$;

drop policy if exists "friend_messages_select" on public.friend_messages;
create policy "friend_messages_select"
on public.friend_messages for select
using (
  (sender_id = auth.uid() or recipient_id = auth.uid())
  and public._are_friends(sender_id, recipient_id)
);

drop policy if exists "friend_messages_insert" on public.friend_messages;
create policy "friend_messages_insert"
on public.friend_messages for insert
with check (
  sender_id = auth.uid()
  and public._are_friends(sender_id, recipient_id)
);

drop policy if exists "friend_dm_reads_select_own" on public.friend_dm_reads;
create policy "friend_dm_reads_select_own"
on public.friend_dm_reads for select
using (user_id = auth.uid());

drop policy if exists "friend_dm_reads_upsert_own" on public.friend_dm_reads;
create policy "friend_dm_reads_upsert_own"
on public.friend_dm_reads for insert
with check (user_id = auth.uid());

drop policy if exists "friend_dm_reads_update_own" on public.friend_dm_reads;
create policy "friend_dm_reads_update_own"
on public.friend_dm_reads for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

alter publication supabase_realtime add table public.friend_messages;

-- DM 스레드 목록 (친구 + 마지막 메시지 + 미확인 수)
create or replace function public.list_friend_dm_threads()
returns table (
  peer_id uuid,
  peer_display_name text,
  last_content text,
  last_at timestamptz,
  unread_count bigint
)
language sql
security definer
set search_path = public
as $$
  with me as (select auth.uid() as uid),
  friends as (
    select fl.peer_id
    from public.friend_links fl, me
    where fl.user_id = me.uid
  ),
  msgs as (
    select
      case when fm.sender_id = me.uid then fm.recipient_id else fm.sender_id end as peer_id,
      fm.content,
      fm.created_at,
      fm.recipient_id,
      fm.sender_id
    from public.friend_messages fm, me
    where fm.sender_id = me.uid or fm.recipient_id = me.uid
  ),
  last_msg as (
    select distinct on (m.peer_id)
      m.peer_id,
      m.content as last_content,
      m.created_at as last_at
    from msgs m
    order by m.peer_id, m.created_at desc
  ),
  reads as (
    select r.peer_id, r.last_read_at
    from public.friend_dm_reads r, me
    where r.user_id = me.uid
  ),
  unread as (
    select m.peer_id, count(*)::bigint as unread_count
    from msgs m
    left join reads r on r.peer_id = m.peer_id
    cross join me
    where m.recipient_id = me.uid
      and m.created_at > coalesce(r.last_read_at, '1970-01-01'::timestamptz)
    group by m.peer_id
  )
  select
    f.peer_id,
    coalesce(nullif(trim(p.display_name), ''), '친구') as peer_display_name,
    lm.last_content,
    lm.last_at,
    coalesce(u.unread_count, 0) as unread_count
  from friends f
  join public.profiles p on p.id = f.peer_id
  left join last_msg lm on lm.peer_id = f.peer_id
  left join unread u on u.peer_id = f.peer_id
  order by lm.last_at desc nulls last, p.display_name;
$$;

revoke all on function public.list_friend_dm_threads() from public;
grant execute on function public.list_friend_dm_threads() to authenticated;

-- 받은 친구 요청 (이름 포함)
create or replace function public.list_incoming_friend_requests()
returns table (
  id uuid,
  from_user_id uuid,
  from_display_name text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    fr.id,
    fr.from_user_id,
    coalesce(nullif(trim(p.display_name), ''), '사용자') as from_display_name,
    fr.created_at
  from public.friend_requests fr
  join public.profiles p on p.id = fr.from_user_id
  where fr.to_user_id = auth.uid()
    and fr.status = 'pending'
  order by fr.created_at desc;
$$;

revoke all on function public.list_incoming_friend_requests() from public;
grant execute on function public.list_incoming_friend_requests() to authenticated;
