#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOBILE_DIR="$ROOT_DIR/apps/mobile"

echo ""
echo "== Study-up: 로컬 실행 준비(Setup) =="
echo "워크스페이스: $ROOT_DIR"
echo ""

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "[필수] Xcode가 필요합니다."
  echo "App Store에서 Xcode 설치 후 다시 실행해주세요."
  echo "열기: https://apps.apple.com/app/xcode/id497799835"
  open "https://apps.apple.com/app/xcode/id497799835" >/dev/null 2>&1 || true
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "[필수] Homebrew가 필요합니다. 설치 페이지를 엽니다."
  open "https://brew.sh" >/dev/null 2>&1 || true
  echo "설치 후 다시 Setup.command를 실행해주세요."
  exit 1
fi

echo ""
echo "== 1) Flutter 설치 확인 =="
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter가 설치되어 있지 않아 Homebrew로 설치를 시도합니다."
  echo "실행: brew install --cask flutter"
  brew install --cask flutter
else
  echo "Flutter 설치됨: $(flutter --version | head -n 1)"
fi

echo ""
echo "== 2) Supabase CLI 설치(선택) =="
if ! command -v supabase >/dev/null 2>&1; then
  echo "Supabase CLI가 없어 설치합니다(로컬 DB가 필요할 때만 사용)."
  brew install supabase/tap/supabase
else
  echo "Supabase CLI 설치됨: $(supabase --version)"
fi

echo ""
echo "== 3) Flutter Doctor 점검 =="
set +e
flutter doctor
DOCTOR_EXIT=$?
set -e
if [ $DOCTOR_EXIT -ne 0 ]; then
  echo ""
  echo "[주의] flutter doctor에 이슈가 있습니다."
  echo "- iOS 실행이 목적이면 Xcode 라이선스/CLI tools, CocoaPods 등이 필요할 수 있어요."
  echo "지금은 계속 진행합니다(필수 이슈는 Run 단계에서 다시 안내됩니다)."
fi

echo ""
echo "== 4) 플랫폼 폴더 생성 (flutter create .) =="
if [ ! -d "$MOBILE_DIR/ios" ] || [ ! -d "$MOBILE_DIR/android" ]; then
  echo "apps/mobile에 iOS/Android 폴더가 없어 생성합니다."
  (cd "$MOBILE_DIR" && flutter create .)
else
  echo "이미 생성됨: ios/, android/"
fi

echo ""
echo "== 5) 의존성 설치 (flutter pub get) =="
(cd "$MOBILE_DIR" && flutter pub get)

echo ""
echo "== 6) .env 설정 확인 =="
if [ ! -f "$MOBILE_DIR/.env" ]; then
  echo "apps/mobile/.env 파일이 없습니다. 예시를 복사합니다."
  cp "$MOBILE_DIR/.env.example" "$MOBILE_DIR/.env"
fi

if grep -q "^SUPABASE_URL=$" "$MOBILE_DIR/.env" || grep -q "^SUPABASE_ANON_KEY=$" "$MOBILE_DIR/.env"; then
  echo ""
  echo "[필수] Supabase 연결 정보가 비어있습니다."
  echo "파일을 열어 값을 채워주세요:"
  echo " - $MOBILE_DIR/.env"
  open "$MOBILE_DIR/.env" >/dev/null 2>&1 || true
  echo ""
  echo "Supabase 프로젝트 생성 후, SQL Editor에서 아래 파일을 실행해야 합니다:"
  echo " - $ROOT_DIR/supabase/migrations/0001_init.sql"
  echo ""
  echo "값을 채운 뒤에는 Run.command를 더블클릭하세요."
else
  echo "Supabase .env 값이 채워져 있습니다."
  echo "이제 Run.command를 실행하면 앱을 볼 수 있어요."
fi

echo ""
echo "== Setup 완료 =="
echo "다음: Run.command (더블클릭)"
echo ""

