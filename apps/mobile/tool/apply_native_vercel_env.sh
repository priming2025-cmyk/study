#!/usr/bin/env bash
# .env 의 SETUDY_APPLE_TEAM_ID / SETUDY_ANDROID_SHA256_FINGERPRINT 를 Vercel Production에 넣고 재배포.
# 사용: apps/mobile 에서  bash tool/apply_native_vercel_env.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

load_env() {
  local f
  for f in "$ROOT/.env" "$ROOT/..env"; do
    if [[ -f "$f" ]]; then
      set -a
      # shellcheck disable=SC1090
      source <(grep -E '^[[:space:]]*(SETUDY_APPLE_TEAM_ID|SETUDY_ANDROID_SHA256_FINGERPRINT|SETUDY_WEB_URL)=' "$f" | sed 's/^[[:space:]]*//')
      set +a
      echo "[env] loaded from $f"
      return 0
    fi
  done
  return 1
}

vercel_set() {
  local name="$1"
  local value="$2"
  echo "[vercel] $name → production"
  npx vercel@latest env add "$name" production --value "$value" --yes 2>/dev/null || \
    npx vercel@latest env add "$name" production --value "$value" --force --yes
}

normalize_sha() {
  local s="$1"
  s="${s//[[:space:]]/}"
  s="${s^^}"
  if [[ "$s" != *:* ]] && [[ ${#s} -eq 64 ]]; then
    echo "$s" | sed -E 's/(..)/\1:/g; s/:$//'
  else
    echo "$s"
  fi
}

if ! load_env; then
  echo "::error::apps/mobile/.env 가 없습니다."
  exit 1
fi

TEAM_ID="${SETUDY_APPLE_TEAM_ID:-}"
TEAM_ID="${TEAM_ID//[[:space:]]/}"
SHA="${SETUDY_ANDROID_SHA256_FINGERPRINT:-}"
SHA="$(normalize_sha "${SHA//[[:space:]]/}")"
WEB_URL="${SETUDY_WEB_URL:-https://setudy.vercel.app}"

HAS_IOS=false
HAS_ANDROID=false

if [[ -n "$TEAM_ID" ]] && [[ "$TEAM_ID" != "TEAMID_REPLACE_ME" ]] && [[ "$TEAM_ID" != "YOUR_TEAM_ID" ]]; then
  if ! [[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "::error::SETUDY_APPLE_TEAM_ID 형식 오류 (10자): $TEAM_ID"
    exit 1
  fi
  HAS_IOS=true
fi

if [[ -n "$SHA" ]] && [[ "$SHA" != "SHA256_REPLACE_ME" ]]; then
  if ! [[ "$SHA" =~ ^([0-9A-F]{2}:){31}[0-9A-F]{2}$ ]]; then
    echo "::error::SETUDY_ANDROID_SHA256_FINGERPRINT 형식 오류 (AA:BB:... 32바이트)"
    exit 1
  fi
  HAS_ANDROID=true
fi

if [[ "$HAS_IOS" == false ]] && [[ "$HAS_ANDROID" == false ]]; then
  echo "::error::SETUDY_APPLE_TEAM_ID 또는 SETUDY_ANDROID_SHA256_FINGERPRINT 중 하나 이상 필요합니다."
  echo "가이드: docs/ios.md"
  exit 1
fi

[[ -n "$WEB_URL" ]] && vercel_set SETUDY_WEB_URL "$WEB_URL"
[[ "$HAS_IOS" == true ]] && vercel_set SETUDY_APPLE_TEAM_ID "$TEAM_ID"
[[ "$HAS_ANDROID" == true ]] && vercel_set SETUDY_ANDROID_SHA256_FINGERPRINT "$SHA"

echo "[vercel] production redeploy..."
npx vercel@latest --prod --yes

echo ""
sleep 5
if [[ "$HAS_IOS" == true ]]; then
  echo "[verify] apple-app-site-association:"
  curl -sf "https://setudy.vercel.app/.well-known/apple-app-site-association" | head -15 || true
  echo "기대 appID: ${TEAM_ID}.com.studyup.student"
fi
if [[ "$HAS_ANDROID" == true ]]; then
  echo ""
  echo "[verify] assetlinks.json:"
  curl -sf "https://setudy.vercel.app/.well-known/assetlinks.json" | head -15 || true
  echo "기대 fingerprint: $SHA"
fi
