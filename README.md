## Study-up (MVP) — On-device 집중도 + 최소 서버

이 저장소는 **얼굴/집중도 추정은 모바일 디바이스에서만 수행**하고, 서버에는 **세션 요약/통계에 필요한 최소 데이터만 저장**하는 Study-up MVP의 구현을 담습니다.

### 핵심 원칙
- **서버로 전송/저장 금지**: 카메라 프레임/사진/영상, 얼굴 임베딩(식별 벡터), 원본 음성
- **서버 저장 허용(요약만)**: 세션 시작/종료, 집중시간(초), 이탈 이벤트 카운트, 앱 전환/일시정지 횟수, 계획표

### 모노레포 구조(초기)
- `apps/mobile/`: Flutter 앱(학생/부모 모드 포함)
- `apps/admin/`: (선택) Next.js 관리자/기관 대시보드
- `supabase/`: 스키마/마이그레이션, Edge Function(최소)
- `docs/`: 아키텍처/정책 문서

### 로컬 실행(준비물)
현재 워크스페이스는 “코드/스키마”만 포함하며, CLI는 개별 설치가 필요합니다.

- Flutter SDK 설치 후:
  - `cd apps/mobile && flutter pub get`
  - `flutter run`

- Supabase CLI 설치 후(로컬 DB 필요 시):
  - `cd supabase`
  - `supabase start`
  - `supabase db reset`

### Supabase(원격) 연결
- 모바일 앱은 Supabase `project url` 과 `anon key` 가 필요합니다.
- 이 값들은 **절대 커밋하지 않고** `.env`/시크릿으로 주입합니다. 예시는 `apps/mobile/.env.example` 를 참고하세요.

