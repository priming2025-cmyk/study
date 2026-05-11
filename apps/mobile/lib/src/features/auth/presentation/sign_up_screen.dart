import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_up/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/ui/app_snacks.dart';
import '../auth_feature_flags.dart';
import '../infra/auth_oauth_launch.dart';
import '../infra/auth_sign_up_error_message.dart';
import 'auth_field_utils.dart';
import 'widgets/auth_brand_header.dart';
import 'widgets/sign_up_email_pending_card.dart';
import 'widgets/sign_up_main_card.dart';

/// 아이디(+내부 pseudo 이메일)·소셜 회원가입 화면.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _loading = false;
  String _role = 'student';
  bool _awaitingEmailVerification = false;

  /// 소셜이 보일 때는 아이디 가입 폼을 접었다가 펼칩니다.
  bool _showLocalSignUp = !AuthFeatureFlags.socialLoginUiEnabled;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    await AuthFieldUtils.commitAutofill();
    if (!mounted) return;
    final validation = AuthFieldUtils.validateSimpleSignUp(
      _username.text,
      _password.text,
      _passwordConfirm.text,
    );
    if (validation != null) {
      AppSnacks.show(context, validation);
      return;
    }
    setState(() => _loading = true);
    try {
      final authEmail = AuthFieldUtils.toAuthEmail(_username.text);
      final res = await supabase.auth.signUp(
        email: authEmail,
        password: _password.text.trim(),
        data: {
          'role': _role,
          'display_login': AuthFieldUtils.normalizeUsername(_username.text),
        },
      );
      if (!mounted) return;
      if (res.session != null) {
        context.go('/');
        return;
      }
      setState(() => _awaitingEmailVerification = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      AppSnacks.show(context, AuthSignUpErrorMessage.forSignUp(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHeader(
                emphasis: 'Study-up',
                trailing: ' 회원가입',
                subtitle: '카카오·네이버·구글 또는 아이디로 빠르게 시작할 수 있어요.',
              ),
              const SizedBox(height: 24),
              if (_awaitingEmailVerification)
                SignUpEmailPendingCard(onGoLogin: () => context.go('/login'))
              else
                SignUpMainCard(
                  loading: _loading,
                  role: _role,
                  onRoleChanged: (r) => setState(() => _role = r),
                  usernameController: _username,
                  passwordController: _password,
                  passwordConfirmController: _passwordConfirm,
                  onSignUp: _signUp,
                  showLocalSignUp: _showLocalSignUp,
                  onToggleLocalSignUp: () =>
                      setState(() => _showLocalSignUp = !_showLocalSignUp),
                  onSocialOAuth: (p) async {
                    if (_loading) return;
                    setState(() => _loading = true);
                    try {
                      await AuthOAuthLaunch.signInWithProvider(context, p);
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
                ),
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
