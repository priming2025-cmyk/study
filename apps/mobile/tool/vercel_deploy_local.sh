#!/usr/bin/env bash
# 로컬 Flutter Web 빌드 후 Vercel Production 배포 (CI Flutter 실패 시 사용)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

load_env() {
  for f in "$ROOT/.env" "$ROOT/..env"; do
    if [[ -f "$f" ]]; then
      set -a
      # shellcheck disable=SC1090
      source "$f"
      set +a
      echo "[env] $f"
      return 0
    fi
  done
  return 1
}

load_env || {
  echo "::error::apps/mobile/.env 필요 (SUPABASE_URL, SUPABASE_ANON_KEY)" >&2
  exit 1
}

export SETUDY_WEB_URL="${SETUDY_WEB_URL:-https://setudy.vercel.app}"
bash tool/generate_well_known.sh

flutter pub get
flutter build web --release --no-tree-shake-icons --no-web-resources-cdn

echo "[vercel] build/web → production (정적 파일만 업로드)"
cd build/web
cp vercel.static.json vercel.json 2>/dev/null || cat > vercel.json <<'EOF'
{
  "installCommand": "echo skip-install",
  "buildCommand": "echo skip-build",
  "outputDirectory": "."
}
EOF
npx vercel@latest deploy --prod --yes --archive=tgz
