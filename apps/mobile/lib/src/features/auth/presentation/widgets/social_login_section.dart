import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/study_up_oauth.dart';

/// 캐시워크류 서비스에서 흔한 **카카오 / 네이버 / 구글** 세 줄 버튼.
class SocialLoginSection extends StatelessWidget {
  const SocialLoginSection({
    super.key,
    required this.enabled,
    required this.onProviderTap,
    this.title = '간편 로그인',
  });

  final bool enabled;
  final Future<void> Function(OAuthProvider provider) onProviderTap;
  final String title;

  static const _kakaoBg = Color(0xFFFEE500);
  static const _kakaoFg = Color(0xFF191919);
  static const _naverBg = Color(0xFF03C75A);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _kakaoBg,
            foregroundColor: _kakaoFg,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: enabled ? () => onProviderTap(OAuthProvider.kakao) : null,
          child: const Text('카카오로 계속하기'),
        ),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _naverBg,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: enabled ? () => onProviderTap(StudyUpOAuth.naver) : null,
          child: const Text('네이버로 계속하기'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: enabled ? () => onProviderTap(OAuthProvider.google) : null,
          child: const Text('Google로 계속하기'),
        ),
      ],
    );
  }
}
