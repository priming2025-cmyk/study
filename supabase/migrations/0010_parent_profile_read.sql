-- 부모가 연결된 자녀의 프로필(표시 이름 등)을 읽을 수 있게 합니다.
-- study_sessions_parent_read 와 함께 쓰면 가족 화면에서 이름을 표시할 수 있습니다.

drop policy if exists "profiles_select_linked_student" on public.profiles;
create policy "profiles_select_linked_student"
on public.profiles for select
using (
  exists (
    select 1 from public.parent_links l
    where l.parent_id = auth.uid()
      and l.student_id = profiles.id
  )
);
