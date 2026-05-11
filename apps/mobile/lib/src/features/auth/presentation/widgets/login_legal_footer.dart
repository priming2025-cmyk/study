import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_up/l10n/app_localizations.dart';

class LoginLegalFooter extends StatelessWidget {
  const LoginLegalFooter({super.key, required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.legalNoticeShort,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '자세한 내용은 이용약관·개인정보처리방침에서 확인하세요.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => context.push('/legal/terms'),
              child: Text(l10n.termsOfService),
            ),
            TextButton(
              onPressed: () => context.push('/legal/privacy'),
              child: Text(l10n.privacyPolicy),
            ),
          ],
        ),
      ],
    );
  }
}
