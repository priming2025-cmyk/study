import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/ui/app_snacks.dart';
import '../infra/auth_login_error_message.dart';
import '../infra/auth_sign_up_error_message.dart';
import 'auth_field_utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _emailLogin = TextEditingController();
  final _pwLogin = TextEditingController();

  final _emailSignUp = TextEditingController();
  final _pwSignUp = TextEditingController();
  final _pwConfirm = TextEditingController();

  bool _loading = false;
  bool _showPwLogin = false;
  bool _showPwSignUp = false;
  bool _showPwConfirm = false;
  bool _saveCredentials = false;

  static const _prefEmailKey = 'login_saved_email';
  static const _prefPasswordKey = 'login_saved_password';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (!mounted) return;
      // TabBarView 대신 IndexedStack을 쓰므로, 탭 변경 시 리빌드가 필요합니다.
      setState(() {});
    });
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_prefEmailKey);
      final password = prefs.getString(_prefPasswordKey);
      if (!mounted) return;
      if (email != null &&
          email.isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        _emailLogin.text = email;
        _pwLogin.text = password;
        setState(() => _saveCredentials = true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tab.dispose();
    _emailLogin.dispose();
    _pwLogin.dispose();
    _emailSignUp.dispose();
    _pwSignUp.dispose();
    _pwConfirm.dispose();
    super.dispose();
  }

  // ── 로그인 ──────────────────────────────────────────────────

  Future<void> _signIn() async {
    await AuthFieldUtils.commitAutofill();
    if (!mounted) return;
    final err = AuthFieldUtils.validateLogin(
      _emailLogin.text,
      _pwLogin.text,
    );
    if (err != null) {
      AppSnacks.show(context, err);
      return;
    }
    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: _emailLogin.text.trim(),
        password: _pwLogin.text.trim(),
      );
      final prefs = await SharedPreferences.getInstance();
      if (_saveCredentials) {
        await prefs.setString(_prefEmailKey, _emailLogin.text.trim());
        await prefs.setString(_prefPasswordKey, _pwLogin.text.trim());
      } else {
        await prefs.remove(_prefEmailKey);
        await prefs.remove(_prefPasswordKey);
      }
      if (!mounted) return;
      context.go('/');
    } on AuthException catch (e) {
      if (!mounted) return;
      AppSnacks.show(context, AuthLoginErrorMessage.forSignIn(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── 회원가입 ─────────────────────────────────────────────────

  Future<void> _signUp() async {
    await AuthFieldUtils.commitAutofill();
    if (!mounted) return;
    final err = AuthFieldUtils.validateSignUp(
      _emailSignUp.text,
      _pwSignUp.text,
      _pwConfirm.text,
    );
    if (err != null) {
      AppSnacks.show(context, err);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await supabase.auth.signUp(
        email: _emailSignUp.text.trim(),
        password: _pwSignUp.text.trim(),
      );
      if (!mounted) return;
      if (res.session != null) {
        // 이메일 인증 비활성화 시 세션이 바로 생성됩니다.
        context.go('/');
        return;
      }
      // 이메일 확인이 필요한 경우 안내
      _showEmailPendingDialog();
    } on AuthException catch (e) {
      if (!mounted) return;
      AppSnacks.show(context, AuthSignUpErrorMessage.forSignUp(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showEmailPendingDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이메일 확인이 필요해요'),
        content: const Text(
          '가입하신 이메일로 확인 메일이 발송됐어요.\n'
          '메일함(또는 스팸)을 확인하고 링크를 클릭하면 바로 로그인할 수 있어요.\n\n'
          '이메일 확인 없이 바로 사용하려면\n'
          'Supabase 대시보드 → Authentication → Providers → Email에서\n'
          '"Confirm email" 옵션을 꺼주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _tab.animateTo(0);
            },
            child: const Text('로그인하러 가기'),
          ),
        ],
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 로고 ──
                  _Logo(color: cs.primary),
                  const SizedBox(height: 36),
                  // ── 탭 ──
                  _AuthTabBar(controller: _tab, disabled: _loading),
                  const SizedBox(height: 28),
                  // ── 탭 내용 ──
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: IndexedStack(
                      key: ValueKey<int>(_tab.index),
                      index: _tab.index,
                      children: [
                        _LoginForm(
                          emailCtrl: _emailLogin,
                          pwCtrl: _pwLogin,
                          showPw: _showPwLogin,
                          onTogglePw: () =>
                              setState(() => _showPwLogin = !_showPwLogin),
                          saveCredentials: _saveCredentials,
                          onSaveCredentialsChanged: (v) =>
                              setState(() => _saveCredentials = v),
                          loading: _loading,
                          onSubmit: _signIn,
                        ),
                        _SignUpForm(
                          emailCtrl: _emailSignUp,
                          pwCtrl: _pwSignUp,
                          confirmCtrl: _pwConfirm,
                          showPw: _showPwSignUp,
                          onTogglePw: () =>
                              setState(() => _showPwSignUp = !_showPwSignUp),
                          showConfirm: _showPwConfirm,
                          onToggleConfirm: () =>
                              setState(() => _showPwConfirm = !_showPwConfirm),
                          loading: _loading,
                          onSubmit: _signUp,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── 하단 안내 ──
                  Text(
                    '얼굴·영상은 서버로 보내지 않아요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.outlineVariant,
                        ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => context.push('/dev/theme'),
                        child: const Text('테마 미리보기 (개발)'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 로고 ─────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  final Color color;
  const _Logo({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.school_rounded, size: 36, color: color),
        ),
        const SizedBox(height: 16),
        Text(
          'setudy',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '계획하고, 집중하고, 성장해요.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

// ── 탭 바 ────────────────────────────────────────────────────

class _AuthTabBar extends StatelessWidget {
  final TabController controller;
  final bool disabled;
  const _AuthTabBar({required this.controller, required this.disabled});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: controller,
        dividerHeight: 0,
        indicator: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(11),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: cs.onPrimary,
        unselectedLabelColor: cs.onSurfaceVariant,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: '로그인'),
          Tab(text: '회원가입'),
        ],
      ),
    );
  }
}

// ── 공통 필드 빌더 ────────────────────────────────────────────

Widget _buildField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  bool obscure = false,
  Widget? suffixIcon,
  TextInputType keyboardType = TextInputType.text,
  TextInputAction action = TextInputAction.next,
  VoidCallback? onSubmit,
  bool enabled = true,
}) {
  return TextFormField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    textInputAction: action,
    enabled: enabled,
    autofillHints: obscure
        ? const [AutofillHints.password]
        : keyboardType == TextInputType.emailAddress
            ? const [AutofillHints.email]
            : null,
    onFieldSubmitted: onSubmit != null ? (_) => onSubmit() : null,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.blue.shade400,
          width: 2,
        ),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}

// ── 로그인 폼 ─────────────────────────────────────────────────

class _LoginForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController pwCtrl;
  final bool showPw;
  final VoidCallback onTogglePw;
  final bool saveCredentials;
  final ValueChanged<bool> onSaveCredentialsChanged;
  final bool loading;
  final VoidCallback onSubmit;

  const _LoginForm({
    required this.emailCtrl,
    required this.pwCtrl,
    required this.showPw,
    required this.onTogglePw,
    required this.saveCredentials,
    required this.onSaveCredentialsChanged,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildField(
          controller: emailCtrl,
          label: '이메일',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: !loading,
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: pwCtrl,
          label: '비밀번호',
          icon: Icons.lock_outline_rounded,
          obscure: !showPw,
          action: TextInputAction.done,
          onSubmit: loading ? null : onSubmit,
          enabled: !loading,
          suffixIcon: IconButton(
            icon: Icon(
              showPw
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
            ),
            onPressed: onTogglePw,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: loading ? null : () => onSaveCredentialsChanged(!saveCredentials),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: saveCredentials,
                  onChanged: loading
                      ? null
                      : (v) => onSaveCredentialsChanged(v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Text(
                    '아이디·비밀번호 저장',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: loading ? null : onSubmit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  '로그인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── 회원가입 폼 ───────────────────────────────────────────────

class _SignUpForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController pwCtrl;
  final TextEditingController confirmCtrl;
  final bool showPw;
  final VoidCallback onTogglePw;
  final bool showConfirm;
  final VoidCallback onToggleConfirm;
  final bool loading;
  final VoidCallback onSubmit;

  const _SignUpForm({
    required this.emailCtrl,
    required this.pwCtrl,
    required this.confirmCtrl,
    required this.showPw,
    required this.onTogglePw,
    required this.showConfirm,
    required this.onToggleConfirm,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildField(
          controller: emailCtrl,
          label: '이메일',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: !loading,
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: pwCtrl,
          label: '비밀번호 (6자 이상)',
          icon: Icons.lock_outline_rounded,
          obscure: !showPw,
          enabled: !loading,
          suffixIcon: IconButton(
            icon: Icon(
              showPw
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
            ),
            onPressed: onTogglePw,
          ),
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: confirmCtrl,
          label: '비밀번호 확인',
          icon: Icons.lock_person_outlined,
          obscure: !showConfirm,
          action: TextInputAction.done,
          onSubmit: loading ? null : onSubmit,
          enabled: !loading,
          suffixIcon: IconButton(
            icon: Icon(
              showConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
            ),
            onPressed: onToggleConfirm,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: loading ? null : onSubmit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  '시작하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          '가입 즉시 로그인됩니다.\n(이메일 인증 없이 바로 사용 가능)',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
