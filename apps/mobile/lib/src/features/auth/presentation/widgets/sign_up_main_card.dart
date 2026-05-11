import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth_feature_flags.dart';
import 'reference_social_auth_strip.dart';
import 'sign_up_simple_form_card.dart';

/// 회원가입: 카카오·네이버·구글 후 「아이디로 가입」 펼치기 + 폼 (애플 없음).
class SignUpMainCard extends StatelessWidget {
  const SignUpMainCard({
    super.key,
    required this.loading,
    required this.role,
    required this.onRoleChanged,
    required this.usernameController,
    required this.passwordController,
    required this.passwordConfirmController,
    required this.onSignUp,
    required this.onSocialOAuth,
    required this.showLocalSignUp,
    required this.onToggleLocalSignUp,
  });

  final bool loading;
  final String role;
  final ValueChanged<String> onRoleChanged;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController passwordConfirmController;
  final VoidCallback onSignUp;
  final Future<void> Function(OAuthProvider p) onSocialOAuth;
  final bool showLocalSignUp;
  final VoidCallback onToggleLocalSignUp;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showForm = showLocalSignUp || !AuthFeatureFlags.socialLoginUiEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (AuthFeatureFlags.socialLoginUiEnabled) ...[
          ReferenceSocialAuthStrip(
            enabled: !loading,
            onProviderTap: onSocialOAuth,
          ),
          const SizedBox(height: 8),
          Text(
            '소셜 가입 후 역할(학생/부모)은 설정에서 바꿀 수 있어요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: loading ? null : onToggleLocalSignUp,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    showLocalSignUp ? '아이디·이메일 가입 접기' : '아이디·이메일로 가입하기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: cs.primary,
                    ),
                  ),
                  Icon(
                    showLocalSignUp ? Icons.expand_less : Icons.chevron_right,
                    size: 20,
                    color: cs.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
        if (showForm) ...[
          const SizedBox(height: 8),
          SignUpSimpleFormCard(
            usernameController: usernameController,
            passwordController: passwordController,
            passwordConfirmController: passwordConfirmController,
            role: role,
            onRoleChanged: onRoleChanged,
            loading: loading,
            onSignUp: onSignUp,
          ),
        ],
      ],
    );
  }
}
