-- Update coin rules + add plan completion bonus (>= 80%)
-- - Focused time: 10 coins per 10 minutes (i.e., 1 coin per minute)
-- - Plan bonus: if today's completion >= 80%, award 10 coins per planned hour (floor(total_target_seconds / 3600))
--   Example: 3h plan => 30 coins
-- Idempotent: each bonus is awarded once per user per day.

-- Extend coin_events to support daily bonus uniqueness
alter table public.coin_events
  add column if not exists plan_date date;

-- Ensure we can award one daily plan bonus per day
do $$ begin
  alter table public.coin_events
    add constraint coin_events_user_plan_date_kind_uniq unique (user_id, plan_date, kind);
exception
  when duplicate_object then null;
end $$;

-- Replace award function with new focused-time rule (1 coin per minute)
create or replace function public.award_coins_for_session(
  p_user_id uuid,
  p_session_id uuid,
  p_focused_seconds integer
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_coins integer;
begin
  if p_focused_seconds is null or p_focused_seconds <= 0 then
    return 0;
  end if;

  -- 10분당 10코인 => 1분당 1코인
  v_coins := floor(p_focused_seconds / 60.0);
  if v_coins <= 0 then
    return 0;
  end if;

  insert into public.coin_events (user_id, session_id, kind, coins, metadata)
  values (
    p_user_id,
    p_session_id,
    'focused_time',
    v_coins,
    jsonb_build_object('focused_seconds', p_focused_seconds)
  )
  on conflict (user_id, session_id, kind) do nothing;

  insert into public.coin_balances (user_id, balance)
  values (p_user_id, v_coins)
  on conflict (user_id) do update
    set balance = public.coin_balances.balance + excluded.balance,
        updated_at = now();

  return v_coins;
end;
$$;

-- Award daily plan bonus if eligible
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
  v_bonus := v_hours * 10;
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
  -- We can't directly know insert success without GET DIAGNOSTICS, so we recompute via found.
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

