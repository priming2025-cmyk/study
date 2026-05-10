#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOBILE_DIR="$ROOT_DIR/apps/mobile"

echo ""
echo "== Study-up: 앱 실행(Run) =="
echo ""

if ! command -v flutter >/dev/null 2>&1; then
  echo "[오류] Flutter가 없습니다. Setup.command를 먼저 실행하세요."
  exit 1
fi

if [ ! -f "$MOBILE_DIR/.env" ]; then
  echo "[오류] apps/mobile/.env가 없습니다. Setup.command를 먼저 실행하세요."
  exit 1
fi

if grep -q "^SUPABASE_URL=$" "$MOBILE_DIR/.env" || grep -q "^SUPABASE_ANON_KEY=$" "$MOBILE_DIR/.env"; then
  echo "[오류] Supabase 환경변수가 비어있습니다."
  echo "파일을 열어 값을 채워주세요: $MOBILE_DIR/.env"
  open "$MOBILE_DIR/.env" >/dev/null 2>&1 || true
  exit 1
fi

echo "== 연결된 디바이스 확인 =="
flutter devices || true

echo ""
echo "== 앱 실행 =="
cd "$MOBILE_DIR"
flutter run

