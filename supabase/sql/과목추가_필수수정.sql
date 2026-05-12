-- =============================================================================
-- Study-up: 과목(plan_items) 추가 패치 (profiles·plan_items 보강)
-- =============================================================================
--
-- 【먼저 확인】 public.profiles 가 없다면 이 파일을 실행하면 안 됩니다.
--   → 저장소의 supabase/migrations/0001_init.sql 전체를 SQL Editor에서
--     먼저 실행한 뒤, 필요하면 0002_auth_profile_trigger.sql 도 실행하세요.
--   → 그 다음에 이 파일을 다시 실행합니다.
--
-- 원인 요약 (기본 스키마가 이미 있을 때):
-- 1) public.profiles 에 RLS INSERT 가 없으면 plans FK 때문에 계획/과목 추가 실패
-- 2) plan_items 에 actual_seconds / is_done / scheduled 컬럼이 없으면 앱 쿼리 실패
--
-- =============================================================================

DO $$
BEGIN
  IF to_regclass('public.profiles') IS NULL THEN
    RAISE EXCEPTION
      'public.profiles 테이블이 없습니다. '
      'Supabase SQL Editor에서 먼저 저장소의 supabase/migrations/0001_init.sql 파일을 '
      '통째로 복사해 실행하세요. 그 다음 supabase/migrations/0002_auth_profile_trigger.sql 을 '
      '실행한 뒤, 마지막으로 이 파일(과목추가_필수수정.sql)을 다시 실행하세요.';
  END IF;
  IF to_regclass('public.plan_items') IS NULL THEN
    RAISE EXCEPTION
      'public.plan_items 테이블이 없습니다. '
      '먼저 supabase/migrations/0001_init.sql 전체를 실행하세요.';
  END IF;
END $$;

-- (1) 프로필: 본인 행만 INSERT 허용
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles for insert
with check (id = auth.uid());

-- (2) plan_items 진행 컬럼 (0003 마이그레이션과 동일)
alter table public.plan_items
  add column if not exists actual_seconds integer not null default 0 check (actual_seconds >= 0),
  add column if not exists is_done boolean not null default false;

create index if not exists plan_items_plan_done_idx on public.plan_items (plan_id, is_done);

-- (3) plan_items 시작 시각·알림 플래그 (0012 마이그레이션과 동일)
alter table public.plan_items
  add column if not exists scheduled_start_at timestamptz,
  add column if not exists reminder_enabled boolean not null default false;

-- 완료 후: 앱에서 새로고침(웹) 또는 재실행, 가능하면 로그아웃 후 다시 로그인.
