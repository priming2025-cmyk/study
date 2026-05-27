# 셋터디 딥링크 (Universal Links / App Links)

초대 링크 `https://setudy.vercel.app/room/join?code=XXXXXX` 를 탭하면:

- **앱 설치됨** → 네이티브 앱이 열리고 셋터디 탭에서 자동 입장 시도
- **앱 없음** → 웹(PWA)으로 열림 (기존 SPA 라우팅)

## Vercel 환경 변수 (필수 — 네이티브 검증용)

| 변수 | 설명 |
|------|------|
| `SETUDY_WEB_URL` | `https://setudy.vercel.app` |
| `SETUDY_APPLE_TEAM_ID` | Apple Developer Team ID (10자) |
| `SETUDY_ANDROID_SHA256_FINGERPRINT` | Android 서명 인증서 SHA-256 |

빌드 시 `tool/generate_well_known.sh` 가 `web/.well-known/` 파일을 생성합니다.

### Android SHA-256 확인

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA256
```

릴리스는 Play Console → 앱 서명 키의 SHA-256 을 사용하세요.

### iOS

1. Xcode → Runner → Signing & Capabilities → **Associated Domains**  
   `applinks:setudy.vercel.app` (이미 `Runner.entitlements` 에 포함)
2. Apple Developer에서 App ID에 Associated Domains 활성화
3. 실제 기기에서 링크 탭 테스트 (시뮬레이터는 제한적)

## 로컬에서 well-known 생성

```bash
cd apps/mobile
export SETUDY_APPLE_TEAM_ID=YOUR_TEAM_ID
export SETUDY_ANDROID_SHA256_FINGERPRINT=AA:BB:...
bash tool/generate_well_known.sh
flutter build web
```

## 앱 패키지

- iOS / Android: `com.studyup.student`
