-- 방장(owner) 위임: RLS의 with check(owner_id = auth.uid()) 때문에 일반 UPDATE로는 불가 → SECURITY DEFINER RPC

create or replace function public.transfer_study_room_host(p_room_id uuid, p_new_owner_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select r.owner_id into v_old
  from public.study_rooms r
  where r.id = p_room_id;

  if v_old is null then
    raise exception 'room not found';
  end if;

  if v_old <> auth.uid() then
    raise exception 'only current host can transfer';
  end if;

  if p_new_owner_id = v_old then
    return;
  end if;

  if not exists (
    select 1
    from public.study_room_members m
    where m.room_id = p_room_id
      and m.user_id = p_new_owner_id
      and m.left_at is null
  ) then
    raise exception 'new host must be an active room member';
  end if;

  update public.study_rooms
  set owner_id = p_new_owner_id
  where id = p_room_id;
end;
$$;

revoke all on function public.transfer_study_room_host(uuid, uuid) from public;
grant execute on function public.transfer_study_room_host(uuid, uuid) to authenticated;
