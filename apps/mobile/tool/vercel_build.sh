#!/usr/bin/env bash
# Vercel(리눅스)에서 Flutter Web 빌드. 대시보드 Root Directory를 apps/mobile 로 두세요.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FLUTTER_DIR="${FLUTTER_DIR:-${ROOT}/.flutter_sdk}"
if [[ ! -x "${FLUTTER_DIR}/bin/flutter" ]]; then
  rm -rf "$FLUTTER_DIR"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
fi
export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter config --enable-web >/dev/null
flutter precache --web
flutter --version
# CI에서는 Android 등 미설치로 `flutter doctor` 가 비정상 종료할 수 있어 생략합니다.

if [[ -z "${SUPABASE_URL:-}" ]] || [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "::error title=Missing env::Vercel Project Settings → Environment Variables 에 SUPABASE_URL, SUPABASE_ANON_KEY 를 넣어 주세요."
  exit 1
fi

# pubspec 에 .env 에셋이 있으므로 빌드 시 생성
PREMIUM="${PREMIUM_VIDEO_ENABLED:-false}"
cat > .env <<EOF
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
PREMIUM_VIDEO_ENABLED=${PREMIUM}
TURN_URL=${TURN_URL:-}
TURN_USERNAME=${TURN_USERNAME:-}
TURN_CREDENTIAL=${TURN_CREDENTIAL:-}
EOF

flutter pub get
flutter build web --release --no-tree-shake-icons

echo "Output: ${ROOT}/build/web"
