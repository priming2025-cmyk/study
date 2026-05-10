## Supabase (MVP)

### 포함 내용
- `migrations/0001_init.sql`: Study-up MVP 스키마 + RLS 정책

### 적용 방법(원격 Supabase)
1. Supabase 프로젝트 생성
2. SQL Editor에서 `migrations/0001_init.sql` 실행
3. Auth 설정에서 Email/Password 또는 Phone 로그인 방식을 선택

### 편한 가입: 이메일 인증(Confirm email) 끄기 (MVP 권장)

가입 직후 비밀번호 로그인까지 막히지 않게 하려면 대시보드에서 **이메일 확인 절차를 끕니다.**

1. [Supabase 대시보드](https://supabase.com/dashboard) → 프로젝트 → **Authentication** → **Providers** → **Email**
2. **Confirm email**(또는 유사 이름: 이메일 확인 필요) 스위치를 **OFF**
3. 저장

이후 `signUp` 응답에 **세션이 바로 내려와** Study-up 앱은 가입 후 홈으로 이동합니다.  
운영 서비스로 갈 때는 스팸·계정 도용 방지를 위해 다시 켜는 경우가 많습니다.

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

### 이메일 로그인·DB만 빠르게 확인할 때 (테스트 체크리스트)
1. **Auth → Providers → Email** 이 켜져 있는지 확인합니다. (개발 중에는 **Confirm email** 을 끄면 가입 직후 로그인까지 수월합니다.)
2. **Authentication → Users** 에서 앱으로 가입한 사용자 UUID가 생겼는지 봅니다.
3. **Table Editor → `public.profiles`** 에 같은 UUID 행이 있는지 봅니다. (`0002_auth_profile_trigger.sql` 등이 적용돼 있으면 가입 시 자동 생성됩니다.)
4. 앱에서 계획·세션 등을 한 번 저장한 뒤, 해당 테이블(`plans`, `session_summaries` 등)에 행이 쌓이는지 확인합니다.
5. **SQL Editor** 예시: `select id, role, created_at from public.profiles order by created_at desc limit 10;`

### 원격 DB에 마이그레이션 반영
- SQL Editor에서 `migrations/*.sql` 을 **순서대로** 실행하거나,
- Supabase CLI로 프로젝트를 링크한 뒤 `supabase db push` 등 팀에서 쓰는 방식으로 맞춥니다.

