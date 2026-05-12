-- Fix: avoid infinite recursion in RLS on public.squad_members
-- Root cause: policy on squad_members queried squad_members again (self-reference).
--
-- Approach:
-- - Create SECURITY DEFINER helper to check membership.
-- - Recreate select policy using the helper (no self-referential subquery in policy).

create or replace function public.is_active_squad_member(p_squad_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.squad_members m
    where m.squad_id = p_squad_id
      and m.user_id = auth.uid()
      and m.left_at is null
  );
$$;

revoke all on function public.is_active_squad_member(uuid) from public;
grant execute on function public.is_active_squad_member(uuid) to authenticated;

-- Replace recursive policy
drop policy if exists "squad_members_select_squad" on public.squad_members;
create policy "squad_members_select_squad"
on public.squad_members for select
using (public.is_active_squad_member(squad_members.squad_id));

