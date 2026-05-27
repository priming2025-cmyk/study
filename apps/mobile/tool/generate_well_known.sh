#!/usr/bin/env bash
# Universal Links / App Links용 .well-known 파일 생성 (flutter build web 전에 실행)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/web/.well-known"
mkdir -p "$OUT"

HOST="${SETUDY_WEB_URL:-https://setudy.vercel.app}"
HOST="${HOST#https://}"
HOST="${HOST#http://}"
HOST="${HOST%%/*}"

TEAM_ID="${SETUDY_APPLE_TEAM_ID:-}"
PKG="com.studyup.student"
SHA="${SETUDY_ANDROID_SHA256_FINGERPRINT:-}"

if [[ -z "$TEAM_ID" ]]; then
  echo "[well-known] SETUDY_APPLE_TEAM_ID 가 없어 iOS Universal Links 검증이 실패할 수 있습니다." >&2
  TEAM_ID="TEAMID_REPLACE_ME"
fi

if [[ -z "$SHA" ]]; then
  echo "[well-known] SETUDY_ANDROID_SHA256_FINGERPRINT 가 없어 Android App Links 검증이 실패할 수 있습니다." >&2
  SHA="SHA256_REPLACE_ME"
fi

# 콜론 없는 64자 hex → AA:BB:... 형식
if [[ "$SHA" != *:* ]] && [[ ${#SHA} -eq 64 ]]; then
  SHA="$(echo "$SHA" | sed -E 's/(..)/\1:/g; s/:$//')"
fi

cat >"$OUT/apple-app-site-association" <<EOF
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "${TEAM_ID}.${PKG}",
        "paths": [
          "/room/join",
          "/room/join/*",
          "/room",
          "/room/*"
        ]
      }
    ]
  }
}
EOF

cat >"$OUT/assetlinks.json" <<EOF
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "${PKG}",
      "sha256_cert_fingerprints": ["${SHA}"]
    }
  }
]
EOF

echo "[well-known] host=${HOST} → ${OUT}/ (iOS appID=${TEAM_ID}.${PKG})"
