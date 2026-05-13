-- Update plan_80_bonus to 15 coins per hour (from 10)
create or replace function public.award_plan_bonus_for_today(
  p_user_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date;
  v_plan_id uuid;
  v_target_seconds integer;
  v_actual_seconds integer;
  v_rate numeric;
  v_hours integer;
  v_bonus integer;
begin
  v_today := (now() at time zone 'UTC')::date;

  select p.id
  into v_plan_id
  from public.plans p
  where p.user_id = p_user_id and p.plan_date = v_today
  limit 1;

  if v_plan_id is null then
    return 0;
  end if;

  select
    coalesce(sum(i.target_seconds), 0),
    coalesce(sum(i.actual_seconds), 0)
  into v_target_seconds, v_actual_seconds
  from public.plan_items i
  where i.plan_id = v_plan_id;

  if v_target_seconds < 3600 then
    -- less than 1h planned => no hour-based bonus
    return 0;
  end if;

  v_rate := v_actual_seconds::numeric / v_target_seconds::numeric;
  if v_rate < 0.8 then
    return 0;
  end if;

  v_hours := floor(v_target_seconds / 3600.0);
  v_bonus := v_hours * 15; -- UPDATED: 10 -> 15 coins per hour

  if v_bonus <= 0 then
    return 0;
  end if;

  -- Idempotent per day
  insert into public.coin_events (user_id, session_id, plan_date, kind, coins, metadata)
  values (
    p_user_id,
    null,
    v_today,
    'plan_80_bonus',
    v_bonus,
    jsonb_build_object(
      'target_seconds', v_target_seconds,
      'actual_seconds', v_actual_seconds,
      'completion_rate', v_rate
    )
  )
  on conflict (user_id, plan_date, kind) do nothing;

  -- If inserted successfully, increase balance.
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

revoke all on function public.award_plan_bonus_for_today(uuid) from public;
grant execute on function public.award_plan_bonus_for_today(uuid) to authenticated;
