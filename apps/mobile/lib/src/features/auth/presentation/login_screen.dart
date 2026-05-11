import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_up/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/ui/app_snacks.dart';
import '../auth_feature_flags.dart';
import '../infra/auth_login_error_message.dart';
import '../infra/auth_oauth_launch.dart';
import 'auth_field_utils.dart';
import 'widgets/auth_brand_header.dart';
import 'widgets/login_identity_form_section.dart';
import 'widgets/login_legal_footer.dart';
import 'widgets/reference_social_auth_strip.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identity = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _showEmailLogin = !AuthFeatureFlags.socialLoginUiEnabled;

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _oauth(OAuthProvider p) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await AuthOAuthLaunch.signInWithProvider(context, p);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signIn() async {
    await AuthFieldUtils.commitAutofill();
    if (!mounted) return;
    final validation = AuthFieldUtils.validateLogin(
      _identity.text,
      _password.text,
    );
    if (validation != null) {
      AppSnacks.show(context, validation);
      return;
    }
    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: AuthFieldUtils.toAuthEmail(_identity.text),
        password: _password.text.trim(),
      );
      if (!mounted) return;
      context.go('/');
    } on AuthException catch (e) {
      if (!mounted) return;
      AppSnacks.show(context, AuthLoginErrorMessage.forSignIn(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accountHelp() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계정·비밀번호 안내'),
        content: const Text(
          '• 아이디로 가입하셨다면 로그인란에는 가입 때 쓴 아이디만 입력하면 됩니다.\n\n'
          '• 이메일로 가입하셨다면 전체 이메일 주소를 입력하세요.\n\n'
          '• 비밀번호 재설정은 Supabase에서 이메일 발송 설정이 되어 있을 때만 가능합니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final showForm = _showEmailLogin || !AuthFeatureFlags.socialLoginUiEnabled;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHeader(
                emphasis: 'Study-up',
                trailing: ' 계정 하나로',
                subtitle: '계획·집중·기록·통계를 한곳에서 시작해요.',
              ),
              if (AuthFeatureFlags.socialLoginUiEnabled)
                const SizedBox(height: 28)
              else
                const SizedBox(height: 20),
              if (AuthFeatureFlags.socialLoginUiEnabled) ...[
                ReferenceSocialAuthStrip(
                  enabled: !_loading,
                  onProviderTap: _oauth,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _showEmailLogin = !_showEmailLogin),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _showEmailLogin ? '이메일·아이디 접기' : '이메일 또는 아이디로 시작하기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: cs.primary,
                          ),
                        ),
                        Icon(
                          _showEmailLogin ? Icons.expand_less : Icons.chevron_right,
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
                LoginIdentityFormSection(
                  identityController: _identity,
                  passwordController: _password,
                  loading: _loading,
                  onSubmit: _signIn,
                ),
              ],
              if (AuthFeatureFlags.socialLoginUiEnabled)
                const SizedBox(height: 20)
              else
                const SizedBox(height: 12),
              if (AuthFeatureFlags.signUpFlowEnabled)
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : () => context.push('/signup'),
                    child: const Text('처음이신가요? 회원가입'),
                  ),
                ),
              Center(
                child: TextButton(
                  onPressed: _accountHelp,
                  child: const Text(
                    '계정·비밀번호 도움말',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              LoginLegalFooter(l10n: l10n),
              const SizedBox(height: 16),
              Text(
                '얼굴/영상은 서버로 보내지 않아요.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.outline,
                    ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.push('/dev/theme'),
                  child: const Text('테마 미리보기 (개발)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
