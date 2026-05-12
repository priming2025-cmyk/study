-- Allow authenticated users to create their own profile row.
-- Without this, plans insert can fail with FK to profiles when the auth trigger
-- is missing or did not run for a user.

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles for insert
with check (id = auth.uid());
