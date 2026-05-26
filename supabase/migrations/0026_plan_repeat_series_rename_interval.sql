-- Fix deployments that ran 0025 with reserved column name `interval` (PostgREST insert fails).
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'plan_repeat_series'
      and column_name = 'interval'
  ) and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'plan_repeat_series'
      and column_name = 'repeat_interval'
  ) then
    alter table public.plan_repeat_series rename column interval to repeat_interval;
  end if;
end $$;
