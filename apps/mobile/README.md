# study_up (Study-up)

## Vercel에 웹 배포

저장소에 이미 포함된 것: `package.json`(`npm run build`), `vercel.json`(빌드/출력/SPA rewrite), `tool/vercel_build.sh`(리눅스에서 Flutter stable 클론 후 `flutter build web`).

1. [Vercel](https://vercel.com) → New Project → 이 GitHub 저장소 선택.
2. **Root Directory** 를 **`apps/mobile`** 으로 지정 (모노레포이므로 필수).
3. Framework Preset 은 자동이면 그대로 두거나 **Other** 로 두어도 됩니다. `vercel.json` 에 `installCommand` / `buildCommand` / `outputDirectory` 가 있습니다.
4. **Environment Variables** (Production·Preview 모두) 에 최소한 다음을 넣습니다. 빌드 스크립트가 이 값으로 `.env` 를 생성합니다.
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - (선택) `PREMIUM_VIDEO_ENABLED`, `TURN_*` — `.env.example` 참고.
5. 배포가 끝나면 나온 **`https://<프로젝트>.vercel.app`** 을 Supabase **Authentication → URL configuration** 의 **Site URL** 및 **Redirect URLs** 에 추가합니다. 소셜 로그인·이메일 링크에 필요합니다.
6. 로컬과 같이 쓰려면 `http://localhost:포트` 도 Redirect URLs 에 넣습니다.

CLI로 미리 보기: `cd apps/mobile && npx vercel` (로그인 후 프리뷰 URL 발급).

빌드 스크립트: `tool/vercel_build.sh` — **첫 빌드는 Flutter SDK 를 클론하므로 5~10분 이상** 걸릴 수 있습니다. 캐시가 있으면 이후가 빨라집니다.

---

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
