-- Coins: minimal ledger + balance for MVP

create table if not exists public.coin_balances (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  balance integer not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.coin_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  session_id uuid references public.study_sessions (id) on delete set null,
  kind text not null, -- e.g. focused_time
  coins integer not null check (coins > 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (user_id, session_id, kind)
);

alter table public.coin_balances enable row level security;
alter table public.coin_events enable row level security;

-- RLS: user can read own balance/events
drop policy if exists "coin_balances_select_own" on public.coin_balances;
create policy "coin_balances_select_own"
on public.coin_balances for select
using (user_id = auth.uid());

drop policy if exists "coin_events_select_own" on public.coin_events;
create policy "coin_events_select_own"
on public.coin_events for select
using (user_id = auth.uid());

-- RPC: award coins for a session (idempotent via unique constraint)
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
  -- Rule (MVP): 1 coin per 10 focused minutes, minimum 1 coin if >= 5 minutes.
  if p_focused_seconds is null or p_focused_seconds <= 0 then
    return 0;
  end if;

  v_coins := floor(p_focused_seconds / 600.0);
  if v_coins <= 0 and p_focused_seconds >= 300 then
    v_coins := 1;
  end if;

  if v_coins <= 0 then
    return 0;
  end if;

  insert into public.coin_events (user_id, session_id, kind, coins, metadata)
  values (p_user_id, p_session_id, 'focused_time', v_coins, jsonb_build_object('focused_seconds', p_focused_seconds))
  on conflict (user_id, session_id, kind) do nothing;

  insert into public.coin_balances (user_id, balance)
  values (p_user_id, v_coins)
  on conflict (user_id) do update
    set balance = public.coin_balances.balance + excluded.balance,
        updated_at = now();

  return v_coins;
end;
$$;

revoke all on function public.award_coins_for_session(uuid, uuid, integer) from public;
grant execute on function public.award_coins_for_session(uuid, uuid, integer) to authenticated;

