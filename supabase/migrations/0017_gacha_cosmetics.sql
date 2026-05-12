-- Gacha cosmetics + coin_events allow spends + pull RPC

alter table public.coin_events
  drop constraint if exists coin_events_coins_check;

alter table public.coin_events
  add constraint coin_events_coins_nonzero check (coins <> 0);

create table if not exists public.cosmetic_items (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('border', 'emote')),
  key text not null unique,
  name_ko text not null,
  rarity text not null default 'common',
  weight integer not null default 1 check (weight > 0)
);

insert into public.cosmetic_items (kind, key, name_ko, rarity, weight) values
  ('border', 'border_soft_pastel', '파스텔 테두리', 'common', 4),
  ('border', 'border_sky', '하늘색 테두리', 'common', 3),
  ('border', 'border_gold', '골드 테두리', 'rare', 1),
  ('emote', 'emote_sparkle', '반짝 이모티콘', 'common', 3),
  ('emote', 'emote_star', '별 이모티콘', 'rare', 1)
on conflict (key) do nothing;

create table if not exists public.user_cosmetics (
  user_id uuid not null references public.profiles (id) on delete cascade,
  item_id uuid not null references public.cosmetic_items (id) on delete cascade,
  obtained_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

create index if not exists user_cosmetics_user_idx on public.user_cosmetics (user_id);

alter table public.cosmetic_items enable row level security;
alter table public.user_cosmetics enable row level security;

drop policy if exists "cosmetic_items_select_all" on public.cosmetic_items;
create policy "cosmetic_items_select_all"
on public.cosmetic_items for select
to authenticated
using (true);

drop policy if exists "user_cosmetics_select_own" on public.user_cosmetics;
create policy "user_cosmetics_select_own"
on public.user_cosmetics for select
using (user_id = auth.uid());

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

  insert into public.coin_balances (user_id, balance)
  values (v_uid, 0)
  on conflict (user_id) do nothing;

  select balance into v_bal from public.coin_balances where user_id = v_uid for update;
  if coalesce(v_bal, 0) < p_cost then
    raise exception 'insufficient_coins';
  end if;

  update public.coin_balances
    set balance = balance - p_cost, updated_at = now()
    where user_id = v_uid;

  insert into public.coin_events (user_id, session_id, kind, coins, metadata)
  values (v_uid, null, 'gacha_spend', -p_cost, jsonb_build_object('cost', p_cost));

  loop
    v_attempts := v_attempts + 1;
    if v_attempts > 8 then
      update public.coin_balances set balance = balance + p_cost, updated_at = now() where user_id = v_uid;
      insert into public.coin_events (user_id, session_id, kind, coins, metadata)
      values (v_uid, null, 'gacha_refund', p_cost, '{}'::jsonb);
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

revoke all on function public.pull_cosmetic_gacha(integer) from public;
grant execute on function public.pull_cosmetic_gacha(integer) to authenticated;

create or replace function public.equip_cosmetic_border(p_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  select id into v_id from public.cosmetic_items where key = p_key and kind = 'border';
  if v_id is null then
    raise exception 'invalid_item';
  end if;
  if not exists (select 1 from public.user_cosmetics where user_id = v_uid and item_id = v_id) then
    raise exception 'not_owned';
  end if;
  update public.profiles set equipped_border_key = p_key where id = v_uid;
end;
$$;

revoke all on function public.equip_cosmetic_border(text) from public;
grant execute on function public.equip_cosmetic_border(text) to authenticated;
