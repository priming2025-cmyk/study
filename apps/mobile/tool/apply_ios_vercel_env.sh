#!/usr/bin/env bash
# 하위 호환: iOS+Android 통합 스크립트 호출
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/apply_native_vercel_env.sh" "$@"
