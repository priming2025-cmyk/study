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
              '가입은 완료됐어요',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '보안 설정에 따라 인증 메일의 링크를 누른 뒤에만 로그인할 수 있어요. '
              '메일함과 스팸함을 확인해 주세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '메일이 오지 않거나 계속 막히면 잠시 뒤 다시 시도하거나, '
              '앱을 만드는 쪽 설정(이메일 인증)을 확인해야 할 수 있어요.',
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
