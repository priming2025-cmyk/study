import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth_feature_flags.dart';
import 'sign_up_simple_form_card.dart';
import 'social_login_section.dart';

/// 회원가입 화면 중앙 카드 (소셜 선택 + 아이디 폼).
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
  });

  final bool loading;
  final String role;
  final ValueChanged<String> onRoleChanged;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController passwordConfirmController;
  final VoidCallback onSignUp;

  /// 소셜 버튼 탭 시 부모에서 로딩 등을 감쌉니다.
  final Future<void> Function(OAuthProvider p) onSocialOAuth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (AuthFeatureFlags.socialLoginUiEnabled) ...[
              SocialLoginSection(
                title: '간편 가입',
                enabled: !loading,
                onProviderTap: onSocialOAuth,
              ),
              const SizedBox(height: 8),
              Text(
                '소셜로 가입하면 역할(학생/부모)은 이후 설정에서 바꿀 수 있어요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '아이디로 간편 가입',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              Text(
                '아이디로 간편 가입',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
            ],
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
        ),
      ),
    );
  }
}
