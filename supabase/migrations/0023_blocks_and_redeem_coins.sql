-- 블럭(in-app 보상 통화; 기존 balance)과 코인(기프티콘 등 교환용) 분리.

-- 1) 잔고: 기존 balance → block_balance, 코인 전용 컬럼 추가
alter table public.coin_balances
  rename column balance to block_balance;

alter table public.coin_balances
  add column if not exists redeem_coin_balance integer not null default 0
    check (redeem_coin_balance >= 0);

-- 2) 이력: 자산 종류 구분 ('block' = 블럭, 'redeem_coin' = 교환 코인)
alter table public.coin_events
  add column if not exists asset text not null default 'block'
    check (asset in ('block', 'redeem_coin'));

-- 연결된 서포터가 학생의 잔고를 조회(교환 UI용)
drop policy if exists "coin_balances_supporter_reads_student" on public.coin_balances;
create policy "coin_balances_supporter_reads_student"
on public.coin_balances for select
to authenticated
using (
  exists (
    select 1 from public.parent_links l
    where l.parent_id = auth.uid()
      and l.student_id = coin_balances.user_id
  )
);

-- ---------------------------------------------------------------------------
-- award_coins_for_session → 블럭 적립 유지 (RPC 이름은 앱 호환용으로 유지)
-- ---------------------------------------------------------------------------
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
  v_blocks integer;
begin
  if p_focused_seconds is null or p_focused_seconds <= 0 then
    return 0;
  end if;

  v_blocks := floor(p_focused_seconds / 60.0);
  if v_blocks <= 0 then
    return 0;
  end if;

  insert into public.coin_events (user_id, session_id, kind, coins, metadata, asset)
  values (
    p_user_id,
    p_session_id,
    'focused_time',
    v_blocks,
    jsonb_build_object('focused_seconds', p_focused_seconds),
    'block'
  )
  on conflict (user_id, session_id, kind) do nothing;

  insert into public.coin_balances (user_id, block_balance)
  values (p_user_id, v_blocks)
  on conflict (user_id) do update
    set block_balance = public.coin_balances.block_balance + excluded.block_balance,
        updated_at = now();

  return v_blocks;
end;
$$;

-- ---------------------------------------------------------------------------
-- 일일 계획 보너스 → 블럭 (0021 규칙 유지)
-- ---------------------------------------------------------------------------
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
    return 0;
  end if;

  v_rate := v_actual_seconds::numeric / v_target_seconds::numeric;
  if v_rate < 0.8 then
    return 0;
  end if;

  v_hours := floor(v_target_seconds / 3600.0);
  v_bonus := v_hours * 15;
  if v_bonus <= 0 then
    return 0;
  end if;

  insert into public.coin_events (user_id, session_id, plan_date, kind, coins, metadata, asset)
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
    ),
    'block'
  )
  on conflict (user_id, plan_date, kind) do nothing;

  if found then
    insert into public.coin_balances (user_id, block_balance)
    values (p_user_id, v_bonus)
    on conflict (user_id) do update
      set block_balance = public.coin_balances.block_balance + excluded.block_balance,
          updated_at = now();
    return v_bonus;
  end if;

  return 0;
end;
$$;

-- ---------------------------------------------------------------------------
-- 스트릭 보너스 → 블럭
-- ---------------------------------------------------------------------------
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

  insert into public.coin_events (user_id, session_id, plan_date, kind, coins, metadata, asset)
  values (
    p_user_id,
    null,
    v_today,
    'streak_bonus_50',
    v_bonus,
    jsonb_build_object('reason', 'plan_80_bonus_consecutive_days'),
    'block'
  )
  on conflict (user_id, plan_date, kind) do nothing;

  if found then
    insert into public.coin_balances (user_id, block_balance)
    values (p_user_id, v_bonus)
    on conflict (user_id) do update
      set block_balance = public.coin_balances.block_balance + excluded.block_balance,
          updated_at = now();
    return v_bonus;
  end if;

  return 0;
end;
$$;

-- ---------------------------------------------------------------------------
-- 가차: 블럭만 차감
-- ---------------------------------------------------------------------------
create or replace function public.pull_cosmetic_gacha(p_cost integer default 50)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_bal integer;
  v_item uuid;
  v_key text;
  v_name text;
  v_kind text;
  v_attempts int := 0;
  v_owned boolean;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  insert into public.coin_balances (user_id, block_balance)
  values (v_uid, 0)
  on conflict (user_id) do nothing;

  select block_balance into v_bal from public.coin_balances where user_id = v_uid for update;
  if coalesce(v_bal, 0) < p_cost then
    raise exception 'insufficient_coins';
  end if;

  update public.coin_balances
    set block_balance = block_balance - p_cost, updated_at = now()
    where user_id = v_uid;

  insert into public.coin_events (user_id, session_id, kind, coins, metadata, asset)
  values (v_uid, null, 'gacha_spend', -p_cost, jsonb_build_object('cost', p_cost), 'block');

  loop
    v_attempts := v_attempts + 1;
    if v_attempts > 8 then
      update public.coin_balances set block_balance = block_balance + p_cost, updated_at = now() where user_id = v_uid;
      insert into public.coin_events (user_id, session_id, kind, coins, metadata, asset)
      values (v_uid, null, 'gacha_refund', p_cost, '{}'::jsonb, 'block');
      return jsonb_build_object('error', 'duplicate_pool_exhausted', 'refunded', true);
    end if;

    select c.id, c.key, c.name_ko, c.kind into v_item, v_key, v_name, v_kind
    from public.cosmetic_items c
    order by -ln(random()) / greatest(1, c.weight)
    limit 1;

    select exists(
      select 1 from public.user_cosmetics uc where uc.user_id = v_uid and uc.item_id = v_item
    ) into v_owned;

    if not v_owned then
      insert into public.user_cosmetics (user_id, item_id) values (v_uid, v_item);
      return jsonb_build_object(
        'item_id', v_item,
        'key', v_key,
        'name_ko', v_name,
        'kind', v_kind,
        'cost', p_cost
      );
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 서포터(연결된 parent_links.parent)가 학생 블럭을 교환 코인으로 전환
-- MVP 규칙: 1 블럭 → 1 코인 (추후 환율·수수료는 별도 정책)
-- ---------------------------------------------------------------------------
create or replace function public.supporter_exchange_blocks_to_redeem_coins(
  p_student_id uuid,
  p_blocks integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supporter uuid := auth.uid();
  v_cur_blocks integer;
  v_redeem integer;
begin
  if v_supporter is null then
    raise exception 'not authenticated';
  end if;
  if p_blocks is null or p_blocks <= 0 then
    raise exception 'invalid_blocks';
  end if;

  if not exists (
    select 1 from public.parent_links l
    where l.parent_id = v_supporter and l.student_id = p_student_id
  ) then
    raise exception 'not_linked_supporter';
  end if;

  insert into public.coin_balances (user_id, block_balance)
  values (p_student_id, 0)
  on conflict (user_id) do nothing;

  select block_balance into v_cur_blocks
  from public.coin_balances
  where user_id = p_student_id
  for update;

  if coalesce(v_cur_blocks, 0) < p_blocks then
    raise exception 'student_insufficient_blocks';
  end if;

  v_redeem := p_blocks;

  update public.coin_balances
  set block_balance = block_balance - p_blocks,
      redeem_coin_balance = redeem_coin_balance + v_redeem,
      updated_at = now()
  where user_id = p_student_id;

  insert into public.coin_events (user_id, session_id, kind, coins, metadata, asset)
  values (
    p_student_id,
    null,
    'supporter_block_out',
    -p_blocks,
    jsonb_build_object('supporter_id', v_supporter, 'converted_to_redeem', v_redeem),
    'block'
  );

  insert into public.coin_events (user_id, session_id, kind, coins, metadata, asset)
  values (
    p_student_id,
    null,
    'supporter_redeem_in',
    v_redeem,
    jsonb_build_object('supporter_id', v_supporter, 'blocks_spent', p_blocks),
    'redeem_coin'
  );

  return jsonb_build_object(
    'student_id', p_student_id,
    'blocks_spent', p_blocks,
    'redeem_coins_granted', v_redeem
  );
end;
$$;

revoke all on function public.supporter_exchange_blocks_to_redeem_coins(uuid, integer) from public;
grant execute on function public.supporter_exchange_blocks_to_redeem_coins(uuid, integer) to authenticated;

