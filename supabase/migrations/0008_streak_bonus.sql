-- Streak bonus: if user achieved plan_80_bonus yesterday AND today, award +50 coins today (once).

create or replace function public.award_streak_bonus_for_today(
  p_user_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date;
  v_yesterday date;
  v_has_today boolean;
  v_has_yesterday boolean;
  v_bonus integer := 50;
begin
  v_today := (now() at time zone 'UTC')::date;
  v_yesterday := v_today - 1;

  -- Ensure today's plan bonus is awarded if eligible (idempotent)
  perform public.award_plan_bonus_for_today(p_user_id);

  select exists (
    select 1 from public.coin_events
    where user_id = p_user_id
      and kind = 'plan_80_bonus'
      and plan_date = v_today
  ) into v_has_today;

  select exists (
    select 1 from public.coin_events
    where user_id = p_user_id
      and kind = 'plan_80_bonus'
      and plan_date = v_yesterday
  ) into v_has_yesterday;

  if not (v_has_today and v_has_yesterday) then
    return 0;
  end if;

  insert into public.coin_events (user_id, session_id, plan_date, kind, coins, metadata)
  values (
    p_user_id,
    null,
    v_today,
    'streak_bonus_50',
    v_bonus,
    jsonb_build_object('reason', 'plan_80_bonus_consecutive_days')
  )
  on conflict (user_id, plan_date, kind) do nothing;

  if found then
    insert into public.coin_balances (user_id, balance)
    values (p_user_id, v_bonus)
    on conflict (user_id) do update
      set balance = public.coin_balances.balance + excluded.balance,
          updated_at = now();
    return v_bonus;
  end if;

  return 0;
end;
$$;

revoke all on function public.award_streak_bonus_for_today(uuid) from public;
grant execute on function public.award_streak_bonus_for_today(uuid) to authenticated;

