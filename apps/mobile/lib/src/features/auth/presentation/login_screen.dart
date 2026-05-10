import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:study_up/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/ui/app_snacks.dart';
import '../infra/auth_oauth_launch.dart';
import 'auth_field_utils.dart';
import 'widgets/social_login_section.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
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
      await supabase.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      if (!mounted) return;
      context.go('/');
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Study-up',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '계획 → 집중 → 기록 → 분석',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SocialLoginSection(
                        enabled: !_loading,
                        onProviderTap: _oauth,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '이메일 로그인',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        TextField(
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: '이메일',
                            hintText: 'name@example.com',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          decoration: const InputDecoration(labelText: '비밀번호'),
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) {
                            if (!_loading) _signIn();
                          },
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _loading ? null : _signIn,
                          child: Text(_loading ? '처리 중…' : '로그인'),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: _loading ? null : () => context.push('/signup'),
                            child: const Text('계정이 없으신가요? 회원가입'),
                          ),
                        ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '얼굴/영상은 서버로 보내지 않아요. 학습 기록은 요약값만 저장합니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
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
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.push('/dev/theme'),
                  child: const Text('테마·컬러 미리보기 (개발 전용)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
