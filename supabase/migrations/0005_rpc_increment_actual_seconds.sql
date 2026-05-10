-- Atomic increment for plan_items.actual_seconds
create or replace function public.increment_plan_item_actual_seconds(
  p_item_id uuid,
  p_delta integer
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.plan_items
  set actual_seconds = greatest(0, actual_seconds + p_delta)
  where id = p_item_id;
$$;

revoke all on function public.increment_plan_item_actual_seconds(uuid, integer) from public;
grant execute on function public.increment_plan_item_actual_seconds(uuid, integer) to authenticated;

