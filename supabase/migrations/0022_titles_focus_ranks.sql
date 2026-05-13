-- Replace early "runner" themed titles with 집중 계급 체계.
-- Keep slugs stable to avoid breaking existing references.

update public.titles set
  name_ko = '집중 새싹',
  min_level = 1,
  sort_order = 10
where slug = 'seed';

update public.titles set
  name_ko = '집중 수련생',
  min_level = 3,
  sort_order = 20
where slug = 'sprout';

update public.titles set
  name_ko = '집중 숙련자',
  min_level = 6,
  sort_order = 30
where slug = 'steady';

update public.titles set
  name_ko = '집중 마스터',
  min_level = 10,
  sort_order = 40
where slug = 'spark';

update public.titles set
  name_ko = '집중의 신',
  min_level = 15,
  sort_order = 50
where slug = 'star';

-- Add extra ranks for a smoother sense of progression.
insert into public.titles (slug, name_ko, min_level, sort_order) values
  ('focus_knight', '집중 기사', 18, 60),
  ('focus_sage', '집중 현자', 22, 70),
  ('focus_archon', '집중 대현자', 26, 80),
  ('focus_legend', '전설의 집중', 30, 90)
on conflict (slug) do nothing;

