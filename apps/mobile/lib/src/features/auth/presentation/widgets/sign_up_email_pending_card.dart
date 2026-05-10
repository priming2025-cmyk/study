import 'package:flutter/material.dart';

/// `signUp` 직후 세션이 없을 때(MVP에서는 주로 「Confirm email」이 켜져 있을 때).
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
              '가입은 되었는데 바로 들어가지 않는 상태예요.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Study-up MVP는 편하게 쓰려면 Supabase에서 이메일 확인을 끄는 것을 권장합니다.\n'
              'Authentication → Providers → Email → 「Confirm email」 OFF → 저장 후, '
              '다시 가입하거나 로그인해 보세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '인증 메일 플로우를 켜 둔 경우에만: 메일의 링크를 누른 뒤 로그인하면 됩니다. '
              '(메일이 없으면 스팸함을 확인해 주세요.)',
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
