-- 친구 찾기: 이름·이메일·UUID로 사용자 검색 (본인 제외, 최대 10명)
create or replace function public.find_users_for_friend(p_query text)
returns table (user_id uuid, display_name text)
language plpgsql
security definer
set search_path = public
as $$
declare
  q text := trim(lower(p_query));
  uid uuid := auth.uid();
  q_uuid uuid;
begin
  if uid is null then
    return;
  end if;
  if length(q) < 2 then
    return;
  end if;

  begin
    q_uuid := p_query::uuid;
  exception
    when others then
      q_uuid := null;
  end;

  return query
  select
    p.id as user_id,
    coalesce(nullif(trim(p.display_name), ''), '사용자') as display_name
  from public.profiles p
  left join auth.users u on u.id = p.id
  where p.id <> uid
    and (
      (q_uuid is not null and p.id = q_uuid)
      or lower(coalesce(p.display_name, '')) like '%' || q || '%'
      or lower(coalesce(u.email, '')) = q
      or lower(coalesce(u.email, '')) like q || '%'
    )
  order by p.display_name nulls last
  limit 10;
end;
$$;

revoke all on function public.find_users_for_friend(text) from public;
grant execute on function public.find_users_for_friend(text) to authenticated;
