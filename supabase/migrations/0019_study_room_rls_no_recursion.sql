-- study_rooms ↔ study_room_members RLS가 서로를 참조해
-- "infinite recursion detected in policy for relation study_rooms" (42P17) 발생.
-- SECURITY DEFINER 헬퍼로 한쪽 체크를 RLS 밖에서 수행해 순환을 끊습니다.

create or replace function public.study_room_owner_id(p_room_id uuid)
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select r.owner_id
  from public.study_rooms r
  where r.id = p_room_id;
$$;

create or replace function public.is_active_study_room_member(p_room_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.study_room_members m
    where m.room_id = p_room_id
      and m.user_id = p_user_id
      and m.left_at is null
  );
$$;

revoke all on function public.study_room_owner_id(uuid) from public;
grant execute on function public.study_room_owner_id(uuid) to authenticated;

revoke all on function public.is_active_study_room_member(uuid, uuid) from public;
grant execute on function public.is_active_study_room_member(uuid, uuid) to authenticated;

-- study_rooms: 멤버십 분기에서 멤버 테이블 RLS를 타지 않도록 함수 사용
drop policy if exists "study_rooms_select_members" on public.study_rooms;
create policy "study_rooms_select_members"
on public.study_rooms for select
using (
  owner_id = (select auth.uid())
  or public.is_active_study_room_member(id, (select auth.uid()))
);

-- study_room_members: 방장 분기에서 study_rooms RLS를 타지 않도록 함수 사용
drop policy if exists "study_room_members_select_member_or_owner" on public.study_room_members;
create policy "study_room_members_select_member_or_owner"
on public.study_room_members for select
using (
  user_id = (select auth.uid())
  or public.study_room_owner_id(room_id) = (select auth.uid())
);
