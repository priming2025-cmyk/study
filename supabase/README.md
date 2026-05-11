## Supabase (MVP)

### 포함 내용
- `migrations/0001_init.sql`: Study-up MVP 스키마 + RLS 정책

### 적용 방법(원격 Supabase)
1. Supabase 프로젝트 생성
2. SQL Editor에서 `migrations/0001_init.sql` 실행
3. Auth 설정에서 Email/Password 또는 Phone 로그인 방식을 선택

### 소셜 로그인 오류: `Unsupported provider: provider is not enabled`

앱에서 카카오·구글·네이버 버튼을 눌렀을 때 JSON으로 `validation_failed` / `provider is not enabled` 가 보이면, **Supabase 프로젝트에 해당 Provider가 아직 켜져 있지 않다**는 뜻입니다. (앱 코드 버그가 아니라 **대시보드 설정** 문제입니다.)

공통으로 먼저 할 일:

1. [Supabase 대시보드](https://supabase.com/dashboard) → 프로젝트 → **Authentication** → **Sign In / Providers** (또는 **Providers**).
2. **Authentication** → **URL configuration** 에서 **Site URL** 과 **Redirect URLs** 에 앱 origin을 넣습니다.  
   - 로컬 예: `http://localhost:포트` (Chrome 실행 시 터미널에 나오는 주소 그대로)  
   - 배포 예: `https://프로젝트.vercel.app`  
   - OAuth 콜백은 Supabase가 처리하므로, **각 외부 서비스(구글·카카오·네이버)** 에는 보통  
     `https://<프로젝트 ref>.supabase.co/auth/v1/callback` 을 등록합니다. (Kakao·Google 콘솔의 Redirect URI)

아래는 **하나씩** 켜는 순서를 권장합니다.

#### 1) Google (가장 단순 — 먼저 여기부터)

1. Supabase → **Providers** → **Google** → **Enable** 후 저장만 해서는 부족하고, **Client IDs** 와 **Client Secret** 이 필요합니다.
2. [Google Cloud Console](https://console.cloud.google.com/) → 프로젝트 → **APIs & Services** → **Credentials** → **OAuth 2.0 Client IDs** 생성 (유형: 웹 애플리케이션).
3. **Authorized redirect URIs** 에  
   `https://<Supabase 프로젝트 ref>.supabase.co/auth/v1/callback`  
   을 추가합니다. (`<Supabase 프로젝트 ref>` 는 Supabase 프로젝트 URL의 서브도메인과 같습니다.)
4. 생성된 **Client ID / Client Secret** 을 Supabase Google Provider 설정에 붙여 넣고 **Save**.

로컬에서 다시 「구글로 시작하기」를 눌러 동작을 확인합니다.

#### 2) Kakao

공식 가이드: [Login with Kakao (Supabase)](https://supabase.com/docs/guides/auth/social-login/auth-kakao)

요약: [Kakao Developers](https://developers.kakao.com/) 앱에서 카카오 로그인·Redirect URI(`…/auth/v1/callback`)·Client Secret 활성화 후, Supabase **Providers → Kakao** 에 REST API 키(클라이언트 ID)·시크릿을 넣고 저장합니다.

#### 3) 네이버

Supabase **기본 제공 목록에 네이버 전용 항목이 없을 수 있습니다.** 이 경우 **Custom OAuth / OIDC** 로 네이버를 추가하고, 대시보드에 표시되는 **Provider ID** 가 앱에서 보내는 값과 **완전히 같아야** 합니다.

Study-up 앱은 기본으로 `OAuthProvider('naver')` 즉 **`naver`** 라는 이름으로 요청합니다. 대시보드에서 만든 커스텀 Provider ID가 `naver` 가 아니면, `apps/mobile/lib/src/features/auth/domain/study_up_oauth.dart` 의 문자열을 대시보드 값에 맞게 바꿉니다.

네이버 개발자센터의 Callback URL에도 동일하게  
`https://<ref>.supabase.co/auth/v1/callback`  
을 등록합니다. (네이버는 **검수·앱 상태**에 따라 로그인 동작이 달라질 수 있습니다.)

---

### 「email rate limit exceeded」 가입 오류

짧은 시간에 가입 시도가 많거나, **확인용 이메일**을 자주 보내면 Supabase 무료 플랜의 **발송 한도**에 걸릴 수 있습니다.

- **대기** 후 재시도 (보통 시간이 지나면 풀립니다).
- 근본적으로 줄이려면 아래처럼 **Confirm email OFF** 로 인증 메일 자체를 끕니다.

### 편한 가입: 이메일 인증(Confirm email) 끄기 (MVP 권장)

가입 직후 비밀번호 로그인까지 막히지 않게 하려면 대시보드에서 **이메일 확인 절차를 끕니다.**

1. [Supabase 대시보드](https://supabase.com/dashboard) → 프로젝트 → **Authentication** → **Providers** → **Email**
2. **Confirm email**(또는 유사 이름: 이메일 확인 필요) 스위치를 **OFF**
3. 저장

이후 `signUp` 응답에 **세션이 바로 내려와** Study-up 앱은 가입 후 홈으로 이동합니다.  
운영 서비스로 갈 때는 스팸·계정 도용 방지를 위해 다시 켜는 경우가 많습니다.

### 앱「아이디만」가입과 Supabase `auth.users.email`

Study-up 앱은 사용자에게 이메일 대신 **아이디**만 받고, 내부적으로 `아이디@users.studyup.internal` 형태로 `signUp`/`signIn` 합니다.  
실제 메일이 도착하지 않는 고정 접미사이므로 **비밀번호 찾기(이메일 링크)** 는 쓰이지 않습니다. 운영에서 본인 확인이 필요하면 이메일·휴대폰 등을 추가하는 편이 좋습니다.

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

