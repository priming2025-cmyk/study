#!/usr/bin/env bash
# Supabase CLI로 원격 DB에 migrations 반영 (supabase login + link + db push)
# DB URI/비밀번호를 저장소에 넣지 않습니다.
#
# 최초 1회:
#   npm run db:supabase-login
# 이후(같은 머신에서 토큰 유지):
#   npm run db:push
#
# link 단계에서 Postgres 비밀번호를 묻는 경우:
#   - 터미널에 직접 입력 (저장 안 됨), 또는
#   - 이 셸에서만: export SUPABASE_DB_PASSWORD='...' 후 npm run db:push
#   (파일·git에 넣지 마세요.)

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SUPA=(npx --yes supabase@latest)

# 원격 ref: 환경변수 → apps/mobile/.env 의 SUPABASE_URL 호스트 순
REF="${SUPABASE_PROJECT_REF:-}"
if [[ -z "$REF" ]]; then
  ENV_FILE="$ROOT/apps/mobile/.env"
  if [[ -f "$ENV_FILE" ]]; then
    URL_LINE="$(grep -E '^[[:space:]]*SUPABASE_URL=' "$ENV_FILE" | head -1 || true)"
    URL_LINE="${URL_LINE#SUPABASE_URL=}"
    URL_LINE="${URL_LINE%\"}"
    URL_LINE="${URL_LINE#\"}"
    URL_LINE="${URL_LINE%/}"
    if [[ "$URL_LINE" =~ https?://([^.]+)\.supabase\.co ]]; then
      REF="${BASH_REMATCH[1]}"
    fi
  fi
fi
if [[ -z "$REF" || "$REF" == YOUR_* ]]; then
  echo "원격 프로젝트 ref 를 알 수 없습니다." >&2
  echo "  export SUPABASE_PROJECT_REF='프로젝트ref' 후 다시 실행하거나," >&2
  echo "  apps/mobile/.env 에 SUPABASE_URL=https://<ref>.supabase.co 형태로 두세요." >&2
  exit 1
fi

echo "→ Supabase 로그인 여부 확인…"
if ! "${SUPA[@]}" projects list --workdir "$ROOT" >/dev/null 2>&1; then
  echo "CLI 로그인이 필요합니다. 다음을 실행한 뒤 다시 시도하세요:" >&2
  echo "  npm run db:supabase-login" >&2
  exit 1
fi

echo "→ 원격 프로젝트 연결(link): $REF"
LINK_ARGS=(link --project-ref "$REF" --workdir "$ROOT" --yes)
if [[ -n "${SUPABASE_DB_PASSWORD:-}" ]]; then
  LINK_ARGS+=(-p "$SUPABASE_DB_PASSWORD")
fi
"${SUPA[@]}" "${LINK_ARGS[@]}"

echo "→ 마이그레이션 푸시(db push)…"
PUSH_ARGS=(db push --linked --yes --workdir "$ROOT")
if [[ -n "${SUPABASE_DB_PASSWORD:-}" ]]; then
  PUSH_ARGS+=(-p "$SUPABASE_DB_PASSWORD")
fi
"${SUPA[@]}" "${PUSH_ARGS[@]}"

echo "완료."
