import 'package:flutter/material.dart';

/// 이메일 인증 대기 안내 (회원가입 직후, 세션이 없을 때).
class SignUpEmailPendingCard extends StatelessWidget {
  const SignUpEmailPendingCard({
    super.key,
    required this.onGoLogin,
  });

  final VoidCallback onGoLogin;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '가입 요청이 완료되었습니다.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '보내드린 메일의 인증 링크를 누른 뒤, 로그인 화면에서 같은 이메일과 비밀번호로 들어오세요. '
              '메일이 없으면 스팸함을 확인해 주세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '개발 중에는 Supabase 대시보드 → Authentication → Providers → Email 에서 '
              '「Confirm email」을 끄면 인증 없이 바로 로그인할 수 있습니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onGoLogin,
              child: const Text('로그인 화면으로'),
            ),
          ],
        ),
      ),
    );
  }
}
