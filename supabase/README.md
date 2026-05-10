## Supabase (MVP)

### 포함 내용
- `migrations/0001_init.sql`: Study-up MVP 스키마 + RLS 정책

### 적용 방법(원격 Supabase)
1. Supabase 프로젝트 생성
2. SQL Editor에서 `migrations/0001_init.sql` 실행
3. Auth 설정에서 Email/Password 또는 Phone 로그인 방식을 선택

### 적용 방법(로컬 Supabase CLI)
1. Supabase CLI 설치
2. 이 폴더에서:
   - `supabase init`
   - `supabase start`
3. 생성된 로컬 DB에 마이그레이션 적용:
   - `supabase db reset`

### 주의
- 얼굴 이미지/영상/임베딩은 **절대 저장하지 않는 설계**입니다.
- 세션은 요약(summaries)만 저장합니다.

