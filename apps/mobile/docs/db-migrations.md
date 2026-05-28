# Supabase DB 마이그레이션 (수동 적용)

CLI `npm run db:push`가 **프로젝트 권한** 오류로 실패할 때, Dashboard에서 SQL을 실행하세요.

## 순서 (권장 — 한 번에)

1. [Supabase Dashboard](https://supabase.com/dashboard) → 프로젝트 `setudy` → **SQL Editor**
2. `supabase/migrations/APPLY_0034_0035_combined.sql` 파일 **전체** 붙여넣기 → **Run**

(또는 0034 → 0035 파일을 각각 실행)

## 적용 후 동작

| 기능 | 필요 마이그레이션 |
|------|-------------------|
| 친구 아님 + 같은 셋터디 DM | 0034 |
| 프로필 사진 `avatar_url` | 0034 |
| 2초 영상 클립 테이블·셀로그 RPC | 0034 + 0035 |

## 만료 클립 자동 삭제 (Edge Function)

```bash
supabase functions deploy purge_expired_video_clips
```

Dashboard → Edge Functions → `purge_expired_video_clips` → Cron: `0 * * * *` (매시간)

환경 변수(선택): `CRON_SECRET` — 호출 시 `Authorization: Bearer <CRON_SECRET>`
