# 셋터디 네이티브 앱 배포 가이드 (iOS · Android)

> **목적**: 아래 **체크리스트 값만 채우면** 스토어 제출·딥링크(Vercel)까지 바로 진행할 수 있게 정리합니다.  
> **패키지 ID**: `com.studyup.student` (iOS Bundle ID / Android applicationId 동일)  
> **딥링크 도메인**: `setudy.vercel.app`  
> **관련**: [deep_links_setup.md](./deep_links_setup.md) · [store_checklist.txt](./store_checklist.txt)

---

## 0. 한눈에 보기 — 지금 배포 준비됐나?

| 항목 | iOS | Android |
|------|-----|---------|
| 앱 코드·패키지 ID | ✅ `com.studyup.student` | ✅ 동일 |
| 딥링크 intent / Associated Domains | ✅ `Runner.entitlements`, Manifest | ✅ `autoVerify` App Links |
| Vercel `/.well-known` | ⚠️ `TEAMID_REPLACE_ME` (Team ID 대기) | ⚠️ `SHA256_REPLACE_ME` (지문 대기) |
| 스토어 **릴리스 서명** | ❌ Apple 멤버십 승인·Xcode Team 대기 | ❌ **debug 키로 release 빌드 중** (Play 출시 불가) |
| 스토어 계정 | ⏳ 구입·승인 최대 48시간 | ❌ Play Console 개발자 등록 필요 ($25 1회) |
| TestFlight / 내부 테스트 | 승인 후 | Play 내부 테스트 트랙 (AAB 업로드 후) |

**결론**

- **웹(PWA)·초대 링크 웹 입장**: 이미 가능 (`https://setudy.vercel.app`)
- **네이티브 링크가 앱으로 열리기**: iOS는 Team ID + 승인 후, Android는 **릴리스 서명 SHA-256** + Vercel 반영 후
- **스토어 정식 출시**: iOS·Android 모두 **아직 추가 작업 필요** (이 문서 체크리스트)

---

## 1. 나중에 채울 값 (복사용 템플릿)

승인·키 발급 후 아래를 채우고 `apps/mobile/.env`에 넣습니다 (git 제외).

```text
# ─── 공통 ───
SETUDY_WEB_URL=https://setudy.vercel.app

# ─── iOS (Apple Developer → Membership, Active 후) ───
SETUDY_APPLE_TEAM_ID=              # 10자, 예: AB12CD34EF

# ─── Android App Links (Play Console → 앱 서명 인증서 SHA-256) ───
SETUDY_ANDROID_SHA256_FINGERPRINT= # 예: AA:BB:CC:... (콜론 포함 32바이트)

# ─── 스토어 설치 링크 (선택, 초대 메시지용) ───
SETUDY_APP_STORE_URL=
SETUDY_PLAY_STORE_URL=

# ─── iOS 메모 ───
IOS_APP_NAME=셋터디
IOS_SKU=setudy-ios-001

# ─── Android 메모 ───
ANDROID_KEYSTORE_PATH=             # 예: ~/setudy-upload-keystore.jks
ANDROID_KEY_ALIAS=upload
# key.properties 는 git에 넣지 않음
```

`.env` 예시:

```env
SETUDY_WEB_URL=https://setudy.vercel.app
SETUDY_APPLE_TEAM_ID=
SETUDY_ANDROID_SHA256_FINGERPRINT=
SETUDY_APP_STORE_URL=
SETUDY_PLAY_STORE_URL=
```

**Vercel에 한 번에 반영** (값을 채운 뒤):

```bash
cd apps/mobile
bash tool/apply_native_vercel_env.sh
# iOS만: SETUDY_APPLE_TEAM_ID 만 있어도 됨
# Android만: SETUDY_ANDROID_SHA256_FINGERPRINT 만 있어도 됨
# 둘 다 있으면 iOS + Android well-known 동시 반영
```

---

## 2. 공통 — 딥링크·Vercel (iOS Universal Links + Android App Links)

초대 URL: `https://setudy.vercel.app/room/join?code=XXXXXX`

| 플랫폼 | 서버 파일 | 필요 환경 변수 |
|--------|-----------|----------------|
| iOS | `/.well-known/apple-app-site-association` | `SETUDY_APPLE_TEAM_ID` |
| Android | `/.well-known/assetlinks.json` | `SETUDY_ANDROID_SHA256_FINGERPRINT` |

빌드 시 `tool/generate_well_known.sh`가 생성합니다. 변수가 없으면 placeholder가 들어가 **앱으로 링크가 열리지 않습니다.**

### 배포 확인

```bash
curl -s https://setudy.vercel.app/.well-known/apple-app-site-association
curl -s https://setudy.vercel.app/.well-known/assetlinks.json
```

- iOS: `TEAMID_REPLACE_ME` → 실제 `{TeamID}.com.studyup.student`
- Android: `SHA256_REPLACE_ME` → 실제 릴리스(앱 서명) 지문

### 실기기 테스트

1. **앱 설치** (서명 인증서가 assetlinks / AASA와 일치해야 함)
2. 메모·카톡 등에 URL 붙여넣기 → 탭
3. 셋터디 앱이 열리며 `/room?join=코드` 입장 시도

---

## 3. Supabase Auth (iOS · Android 공통)

Dashboard → **Authentication** → **URL configuration**

| 항목 | 권장 |
|------|------|
| Site URL | `https://setudy.vercel.app` |
| Redirect URLs | `setudy://auth-callback` |

코드: `lib/src/core/supabase/auth_redirect_config.dart`

---

# Part A — iOS

## A-1. 지금 상태 (멤버십 구입·승인 대기)

[Apple Developer 계정](https://developer.apple.com/account)에서:

> 멤버십을 구입하시기 바랍니다.  
> 구입을 처리하는 데 **최대 48시간**이 소요될 수 있습니다.

| 승인 전 | 승인 후 |
|---------|---------|
| Team ID 미표시 | Membership **Active** + Team ID 10자 |
| 인증서·TestFlight 불가 | Xcode 서명·제출 가능 |

**승인 전에 할 일**: 스크린샷, 개인정보 문구, Supabase URL, 이 문서 1절 템플릿 작성.

---

## A-2. Team ID 찾기 (Membership)

1. [developer.apple.com/account](https://developer.apple.com/account) 로그인  
2. **Account → Membership**  
3. **Team ID** — 영문 대문자+숫자 **10자**  
4. `.env` → `SETUDY_APPLE_TEAM_ID`  

공식: [Locate your Team ID](https://developer.apple.com/help/account/manage-your-team/locate-your-team-id)

Xcode: **Settings → Accounts** → 팀 선택 후 Team ID 확인.

---

## A-3. Apple Developer 포털 (승인 후 1회)

1. [Identifiers](https://developer.apple.com/account/resources/identifiers/list) → App ID  
2. Bundle ID: `com.studyup.student`  
3. Capabilities: **Associated Domains** (필수), Push(선택)  
4. entitlements: `ios/Runner/Runner.entitlements` → `applinks:setudy.vercel.app`

---

## A-4. Xcode 빌드 · TestFlight

```bash
cd apps/mobile
flutter pub get
flutter run -d <device_id>    # 실기기
# 또는 Xcode: ios/Runner.xcworkspace → Archive → Distribute
```

| 확인 | 위치 |
|------|------|
| Bundle ID | Runner → General |
| Signing Team | Signing & Capabilities |
| Associated Domains | Runner.entitlements |
| 카메라·마이크 문구 | Info.plist |

[App Store Connect](https://appstoreconnect.apple.com) → 앱 생성 → TestFlight → 심사.

`SETUDY_APP_STORE_URL`에 TestFlight/스토어 URL을 넣으면 초대 메시지에 포함됩니다.

---

## A-5. iOS 체크리스트

- [ ] Membership **Active** + Team ID  
- [ ] `.env` → `SETUDY_APPLE_TEAM_ID`  
- [ ] `bash tool/apply_native_vercel_env.sh`  
- [ ] AASA에 실제 Team ID 확인 (`curl`)  
- [ ] App ID + Associated Domains  
- [ ] Xcode 서명·실기기 빌드  
- [ ] 초대 링크 실기기 테스트  
- [ ] TestFlight / App Store 제출  

**Team ID만 알려주시면** Vercel AASA 반영·재배포·검증까지 대신 진행 가능합니다.

---

# Part B — Android

## B-1. 지금 상태 — 코드는 준비됐지만 **스토어 출시는 미완**

### 이미 되어 있는 것 ✅

| 항목 | 파일 |
|------|------|
| `applicationId` | `android/app/build.gradle.kts` → `com.studyup.student` |
| App Links (`autoVerify`) | `AndroidManifest.xml` → `https://setudy.vercel.app/room` |
| Flutter 딥링크 라우팅 | `app_links` + `app_deep_link_listener.dart` |

### 아직 해야 하는 것 ❌

| 항목 | 이유 |
|------|------|
| **릴리스 서명 키** | `build.gradle.kts`의 release가 **debug 키** 사용 중 → Play Store 업로드·정식 App Links 불가 |
| **Play Console 개발자** | [Google Play Console](https://play.google.com/console) 등록 ($25, 1회) |
| **SHA-256 → Vercel** | live `assetlinks.json`이 `SHA256_REPLACE_ME` 상태 |
| 스토어 등록정보 | 스크린샷, 개인정보, 콘텐츠 등급, 데이터 안전 |

> **로컬 debug 빌드**만 할 때는 `~/.android/debug.keystore` 지문으로 테스트할 수 있지만, **프로덕션 도메인**(`setudy.vercel.app`) App Links는 **Play에 올릴 앱과 같은 서명 지문**을 Vercel에 넣어야 합니다.

---

## B-2. SHA-256 지문 — 어디서·어떻게 찾나?

Android App Links는 **앱에 서명한 인증서의 SHA-256**이 `assetlinks.json`과 일치해야 합니다.

### ✅ 권장: Play Console「앱 서명」인증서 (스토어 배포 시)

Google Play **앱 서명**을 쓰면 최종 APK/AAB는 Google이 다시 서명합니다.  
→ Vercel에는 **업로드 키가 아니라「앱 서명 키」SHA-256**을 넣어야 합니다.

1. [Play Console](https://play.google.com/console) → 앱 선택  
2. **Release** → **Setup** → **App integrity** (또는 **앱 서명**)  
3. **App signing key certificate** → **SHA-256 certificate fingerprint** 복사  
4. `.env` → `SETUDY_ANDROID_SHA256_FINGERPRINT=AA:BB:...`

### 업로드 키만 있는 경우 (첫 AAB 업로드 전)

아직 Play에 앱을 안 올렸다면, **업로드 keystore**를 먼저 만들고 그 지문으로 Vercel을 맞출 수 있습니다.  
Play 앱 서명 활성화 후에는 **콘솔의 앱 서명 키 지문으로 다시 Vercel을 갱신**하세요.

```bash
keytool -list -v -keystore /path/to/upload-keystore.jks -alias upload | grep -i SHA256
```

(Java 필요: `brew install --cask temurin` 등)

### 로컬 debug만 (개발·내부 테스트)

```bash
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android | grep SHA256
```

`flutter run`으로 한 번 빌드하면 `~/.android/debug.keystore`가 생깁니다.  
**프로덕션 링크 검증용으로는 debug 지문을 Vercel에 넣지 마세요** (출시 앱과 다름).

---

## B-3. 릴리스 서명 설정 (Play 업로드 전 필수)

현재 `android/app/build.gradle.kts`:

```kotlin
release {
    signingConfig = signingConfigs.getByName("debug")  // ← 출시 전 변경 필요
}
```

### 권장 절차

1. **업로드 keystore 생성** (1회, 분실 시 복구 불가 — 백업 필수)

```bash
keytool -genkey -v -keystore ~/setudy-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. `android/key.properties` 생성 (**git에 커밋하지 않음**)

```properties
storePassword=****
keyPassword=****
keyAlias=upload
storeFile=/Users/you/setudy-upload-keystore.jks
```

3. `android/app/build.gradle.kts`에 `signingConfigs` + release에 연결  
   (구현은 `android/.gitignore`에 `key.properties` 추가 후 진행)

4. 릴리스 빌드

```bash
cd apps/mobile
flutter build appbundle --release
# 출력: build/app/outputs/bundle/release/app-release.aab
```

5. Play Console → **내부 테스트** 트랙에 AAB 업로드  
6. **앱 서명 키 SHA-256** 확인 → `.env` → Vercel 반영 (`apply_native_vercel_env.sh`)

---

## B-4. Google Play Console (출시 흐름)

| 단계 | 작업 |
|------|------|
| 1 | [Play Console](https://play.google.com/console) 개발자 등록 ($25) |
| 2 | **앱 만들기** → 패키지명 `com.studyup.student` |
| 3 | 스토어 등록: 이름, 설명, 스크린샷, 개인정보 처리방침 URL |
| 4 | **데이터 안전** · **콘텐츠 등급** 설문 |
| 5 | `app-release.aab` 업로드 → **내부 테스트** → 테스터 추가 |
| 6 | 앱 서명 SHA-256 → Vercel `SETUDY_ANDROID_SHA256_FINGERPRINT` |
| 7 | `bash tool/apply_native_vercel_env.sh` |
| 8 | 실기기에서 초대 링크 테스트 |

`SETUDY_PLAY_STORE_URL`에 스토어/오픈 테스트 링크를 넣으면 초대 메시지에 포함됩니다.

### App Links 검증 (adb, 앱 설치 후)

```bash
adb shell pm get-app-links com.studyup.student
adb shell pm verify-app-links --re-verify com.studyup.student
```

`setudy.vercel.app` 도메인이 **verified** 여야 합니다.

---

## B-5. Android 체크리스트

- [ ] Play Console 개발자 등록  
- [ ] 업로드 keystore 생성·백업  
- [ ] `build.gradle.kts` release 서명 (debug 제거)  
- [ ] `flutter build appbundle --release`  
- [ ] Play 내부 테스트 트랙 업로드  
- [ ] **앱 서명 키 SHA-256** → `.env`  
- [ ] `bash tool/apply_native_vercel_env.sh`  
- [ ] `curl`로 `assetlinks.json` placeholder 제거 확인  
- [ ] 실기기 링크 테스트 · `pm get-app-links`  
- [ ] (선택) `SETUDY_PLAY_STORE_URL` 설정  

**SHA-256 지문만 알려주시면** Vercel `assetlinks.json` 반영·재배포·검증까지 진행 가능합니다.

---

## 8. 통합 배포 순서 (승인·키 확보 후)

## 8-A. (중요) 앱 종료 상태 DM 푸시(FCM/APNs) — **지금은 일시 중지**

### 현재 기본 설정 (아이디·키 없이 테스트)

| 기능 | 아이디/키 없이 | 비고 |
|------|----------------|------|
| 로그인·친구·DM 저장·답장 | ✅ 가능 | Supabase만 사용 |
| 앱 **켜져 있을 때** DM 수신·로컬 알림 | ✅ 가능 | Realtime + 기존 리스너 |
| 계획 **5분 전** 알림 (`셋터디 5분 전입니다`) | ✅ 가능 | 로컬 알림, Firebase 불필요 |
| 앱 **완전 종료** 후 DM 푸시 | ⏸ **중지** | FCM/APNs 설정 전 |

앱 코드 기본값: `apps/mobile/.env` 에 **`SETUDY_FCM_ENABLED=false`** (또는 미설정 = 꺼짐).

```bash
# 지금 테스트할 때 (.env)
SETUDY_FCM_ENABLED=false
```

Firebase·APNs를 다 준비한 뒤에만 아래로 바꿉니다.

```bash
# 종료 상태 푸시 켜기 (준비 완료 후)
SETUDY_FCM_ENABLED=true
```

그다음 **8-A-1 ~ 8-A-3 체크리스트**를 순서대로 진행하고, 앱을 다시 빌드·실기기 테스트하세요.

---

Setudy는 **DB/실시간(Supabase)** 위에 올라가 있고, **앱이 꺼져 있을 때 푸시 “배달”만** iOS/Android 시스템을 통해 이루어집니다.  
**사용자(학생)에게 Firebase 로그인/아이디는 필요 없고**, **개발자(나)가 나중에 채울 설정값/키**만 필요합니다.  
(지금은 위 표처럼 **종료 푸시만 멈춰 두었고**, 나머지는 그대로 테스트 가능합니다.)

### 8-A-1. 당신(개발자)이 준비해야 하는 값 (잊지 말기용)

아래 값들은 “Firebase 아이디(계정)”을 저에게 주는 개념이 아니라, **Firebase 콘솔에서 프로젝트를 만들고 나오는 설정값/키**입니다.

- **Firebase 프로젝트 ID**: `______________`  
- **iOS Bundle ID** (Xcode의 Runner): `______________`  
- **Apple Team ID (10자)**: `______________`  
- **APNs Auth Key** (Apple Developer → Keys)
  - **Key ID**: `______________`
  - **Team ID**: `______________`
  - **.p8 파일**: (로컬에만 보관, Git 업로드 금지)
- **FCM Service Account JSON** (서버 발송용)
  - Supabase Edge Function 환경변수로 넣을 값: `FIREBASE_SERVICE_ACCOUNT_JSON`
  - (로컬/Git에 넣지 말고) Supabase Functions Secrets로만 관리

### 8-A-2. Supabase(서버) 쪽 준비

- [ ] `public.fcm_tokens` 테이블 존재 (`0033_fcm_tokens.sql`)  
- [ ] Supabase Edge Function `send_friend_dm_push` 배포  
- [ ] Edge Function secrets 설정:
  - [ ] `FIREBASE_PROJECT_ID`
  - [ ] `FIREBASE_SERVICE_ACCOUNT_JSON`
  - [ ] `SUPABASE_SERVICE_ROLE_KEY`

### 8-A-3. iOS 앱 쪽 준비 (Xcode) — `SETUDY_FCM_ENABLED=true` **이후**

1. [ ] Apple Developer Membership Active  
2. [ ] Firebase 콘솔에서 iOS 앱 등록 (Bundle ID = Runner와 동일)  
3. [ ] `apps/mobile` 에서 `flutterfire configure` → `lib/firebase_options.dart` 생성  
4. [ ] `GoogleService-Info.plist` 를 `ios/Runner/` 에 추가 (Xcode Runner 타깃 포함)  
5. [ ] Xcode: **Push Notifications** capability  
6. [ ] Xcode: **Background Modes → Remote notifications**  
7. [ ] `.env` 에 `SETUDY_FCM_ENABLED=true` 저장 후 앱 재빌드  
8. [ ] 실기기에서 푸시 권한 허용 확인  

### 8-A-4. 중요한 설계 원칙(공부 방해 방지)

- **공부 중(혼자 공부/셋터디 방 참여)** 에는 푸시를 표시하지 않도록 앱이 로컬 상태(`setudy_is_studying`)로 억제합니다.
- FCM은 **data-only**로 보내고, 실제 알림 표시 여부는 앱이 결정합니다.

### 웹 딥링크 서버 (Vercel) — iOS + Android

- [ ] `SETUDY_APPLE_TEAM_ID` (iOS)  
- [ ] `SETUDY_ANDROID_SHA256_FINGERPRINT` (Android, Play 앱 서명 키)  
- [ ] `bash tool/apply_native_vercel_env.sh`  
- [ ] `curl`로 AASA + assetlinks 확인  

### iOS 앱 바이너리

- [ ] Apple Membership Active  
- [ ] Xcode 서명 · TestFlight  

### Android 앱 바이너리

- [ ] 릴리스 keystore · AAB  
- [ ] Play 내부/공개 테스트  

### 공통

- [ ] Supabase Redirect URLs  
- [ ] 스토어 스크린샷·개인정보 ([store_checklist.txt](./store_checklist.txt))  

---

## 9. 자주 묻는 문제

### Q. Android는 iOS처럼 48시간 대기가 있나요?

- **Play Console**: 결제 후 보통 빠르게 활성화 (계정마다 다름).  
- **앱 심사**: 내부 테스트는 짧고, 프로덕션은 심사 며칠 가능.  
- **App Links**: 계정 승인과 별개로, **SHA-256 + Vercel 배포**만 맞으면 내부 테스트 APK에서도 검증 가능.

### Q. debug로 빌드한 앱에서 프로덕션 링크가 안 열려요

- Vercel `assetlinks.json`은 **릴리스(앱 서명) 지문** 기준이어야 합니다.  
- debug APK + 프로덕션 assetlinks 조합은 일치하지 않습니다.

### Q. iOS Team ID / Android SHA만 주면 되나요?

| 보내주실 값 | 제가 할 수 있는 것 |
|-------------|-------------------|
| Team ID 10자 | Vercel AASA + 재배포 + 확인 |
| SHA-256 지문 | Vercel assetlinks + 재배포 + 확인 |
| 둘 다 | well-known 전체 반영 |

스토어에 **앱 파일 업로드**(Archive, AAB)는 본인 Mac/Play Console에서 진행해야 합니다.

---

## 10. 관련 파일

| 파일 | 역할 |
|------|------|
| `ios/Runner/Runner.entitlements` | iOS Associated Domains |
| `android/app/src/main/AndroidManifest.xml` | Android App Links |
| `android/app/build.gradle.kts` | applicationId, **release 서명 (TODO)** |
| `tool/generate_well_known.sh` | AASA + assetlinks 생성 |
| `tool/apply_native_vercel_env.sh` | `.env` → Vercel + 재배포 |
| `tool/apply_ios_vercel_env.sh` | 위 스크립트 호환 래퍼 |
| `.env.example` | 환경 변수 템플릿 (`SETUDY_FCM_ENABLED` 포함) |
| `lib/src/core/push/push_feature_config.dart` | 종료 푸시 on/off (`SETUDY_FCM_ENABLED`) |
| `lib/src/core/push/push_notifications.dart` | FCM 초기화 (플래그 true일 때만) |
