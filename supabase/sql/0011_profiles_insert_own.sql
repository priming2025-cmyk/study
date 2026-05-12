-- migrations/0011_profiles_insert_own.sql 과 동일합니다.
-- 원격 적용: 저장소 루트에서 `npm run db:supabase-login` → `npm run db:push`
-- (supabase/sql 폴더에서만 찾는 경우를 위해 복사본을 둠)
--
-- Allow authenticated users to create their own profile row.
-- Without this, plans insert can fail with FK to profiles when the auth trigger
-- is missing or did not run for a user.

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles for insert
with check (id = auth.uid());
