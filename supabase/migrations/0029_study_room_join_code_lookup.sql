-- 입장코드로 방 조회: 멤버가 아닌 사용자도 RLS 없이 id·메타만 조회 (SECURITY DEFINER).
-- study_rooms SELECT 정책은 방장/기존 멤버만 허용 → 입장 전에는 join_code 조회가 막혀 있었음.

create or replace function public.lookup_study_room_for_join(p_entry text)
returns json
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_entry text := nullif(trim(p_entry), '');
  v_row public.study_rooms%rowtype;
begin
  if v_entry is null then
    return null;
  end if;

  if v_entry ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select * into v_row
    from public.study_rooms
    where id = v_entry::uuid;
  else
    select * into v_row
    from public.study_rooms
    where upper(trim(join_code)) = upper(trim(v_entry));
  end if;

  if not found then
    return null;
  end if;

  return json_build_object(
    'id', v_row.id,
    'owner_id', v_row.owner_id,
    'join_code', v_row.join_code,
    'name', v_row.name,
    'max_peers', v_row.max_peers
  );
end;
$$;

revoke all on function public.lookup_study_room_for_join(text) from public;
grant execute on function public.lookup_study_room_for_join(text) to authenticated;
