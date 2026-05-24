-- 셋터디방 퇴장 보너스 (세션당 1회, kind = study_room_bonus)
create or replace function public.award_study_room_bonus_for_session(
  p_user_id uuid,
  p_session_id uuid,
  p_blocks integer
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_blocks is null or p_blocks <= 0 then
    return 0;
  end if;

  insert into public.coin_events (user_id, session_id, kind, coins, metadata, asset)
  values (
    p_user_id,
    p_session_id,
    'study_room_bonus',
    p_blocks,
    jsonb_build_object('source', 'study_room'),
    'block'
  )
  on conflict (user_id, session_id, kind) do nothing;

  insert into public.coin_balances (user_id, block_balance)
  values (p_user_id, p_blocks)
  on conflict (user_id) do update
    set block_balance = public.coin_balances.block_balance + excluded.block_balance,
        updated_at = now();

  return p_blocks;
end;
$$;

revoke all on function public.award_study_room_bonus_for_session(uuid, uuid, integer) from public;
grant execute on function public.award_study_room_bonus_for_session(uuid, uuid, integer) to authenticated;
