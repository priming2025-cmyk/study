-- FCM 토큰 저장 (수신자 푸시 발송용)

create table if not exists public.fcm_tokens (
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  device_platform text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

create index if not exists fcm_tokens_token_idx
  on public.fcm_tokens (token);

alter table public.fcm_tokens enable row level security;

drop policy if exists "fcm_tokens_select_own" on public.fcm_tokens;
create policy "fcm_tokens_select_own"
on public.fcm_tokens for select
using (user_id = auth.uid());

drop policy if exists "fcm_tokens_upsert_own" on public.fcm_tokens;
create policy "fcm_tokens_upsert_own"
on public.fcm_tokens for insert
with check (user_id = auth.uid());

drop policy if exists "fcm_tokens_update_own" on public.fcm_tokens;
create policy "fcm_tokens_update_own"
on public.fcm_tokens for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

