import 'package:flutter/material.dart';

/// 로그인·가입 상단 브랜드 문구 (참고 화면 스타일).
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    required this.emphasis,
    required this.trailing,
    required this.subtitle,
    this.brandAccentColor,
  });

  final String emphasis;
  final String trailing;
  final String subtitle;

  final Color? brandAccentColor;

  @override
  Widget build(BuildContext context) {
    final accent = brandAccentColor ?? Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
            children: [
              TextSpan(
                text: emphasis,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(text: trailing),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}
