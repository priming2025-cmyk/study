-- Auto-create profile row when a new auth user signs up.
-- Role is derived from auth.users.raw_user_meta_data.role when present.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  role_text text;
begin
  role_text := coalesce(new.raw_user_meta_data->>'role', 'student');

  insert into public.profiles (id, role, display_name)
  values (
    new.id,
    role_text::public.user_role,
    coalesce(new.raw_user_meta_data->>'display_name', null)
  )
  on conflict (id) do nothing;

  return new;
exception
  when others then
    -- If role cast fails or any issue occurs, fallback to student.
    insert into public.profiles (id, role)
    values (new.id, 'student')
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

