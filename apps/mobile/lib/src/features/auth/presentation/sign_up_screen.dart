import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_up/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/ui/app_snacks.dart';
import '../infra/auth_oauth_launch.dart';
import 'auth_field_utils.dart';
import 'widgets/sign_up_email_form_card.dart';
import 'widgets/sign_up_email_pending_card.dart';
import 'widgets/social_login_section.dart';

/// 이메일 회원가입 전용 화면 (로그인과 분리).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String _role = 'student';
  bool _awaitingEmailVerification = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    await AuthFieldUtils.commitAutofill();
    if (!mounted) return;
    final validation = AuthFieldUtils.validateEmailPassword(
      _email.text,
      _password.text,
    );
    if (validation != null) {
      AppSnacks.show(context, validation);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await supabase.auth.signUp(
        email: _email.text.trim(),
        password: _password.text.trim(),
        data: {'role': _role},
      );
      if (!mounted) return;
      if (res.session != null) {
        context.go('/');
        return;
      }
      setState(() => _awaitingEmailVerification = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      AppSnacks.show(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _oauth(OAuthProvider provider) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthOAuthLaunch.signInWithProvider(context, provider);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
          tooltip: '로그인으로',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Study-up',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '계획 → 집중 → 기록 → 분석',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              if (_awaitingEmailVerification)
                SignUpEmailPendingCard(onGoLogin: () => context.go('/login'))
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SocialLoginSection(
                          title: '간편 가입',
                          enabled: !_loading,
                          onProviderTap: _oauth,
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
                                '이메일로 가입',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SignUpEmailFormCard(
                          emailController: _email,
                          passwordController: _password,
                          role: _role,
                          onRoleChanged: (r) => setState(() => _role = r),
                          loading: _loading,
                          onSignUp: _signUp,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                l10n.legalNoticeShort,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
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
          ),
        ),
      ),
    );
  }
}
