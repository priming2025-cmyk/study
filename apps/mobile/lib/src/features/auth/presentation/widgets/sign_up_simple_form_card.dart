import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 아이디 + 비밀번호 + 확인 (Supabase에는 pseudo 이메일로 전송).
class SignUpSimpleFormCard extends StatelessWidget {
  const SignUpSimpleFormCard({
    super.key,
    required this.usernameController,
    required this.passwordController,
    required this.passwordConfirmController,
    required this.role,
    required this.onRoleChanged,
    required this.loading,
    required this.onSignUp,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController passwordConfirmController;
  final String role;
  final ValueChanged<String> onRoleChanged;
  final bool loading;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '역할',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'student', label: Text('학생')),
              ButtonSegment(value: 'parent', label: Text('부모')),
            ],
            selected: {role},
            onSelectionChanged: (s) => onRoleChanged(s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: usernameController,
            decoration: const InputDecoration(
              labelText: '아이디',
              hintText: '영문 소문자·숫자·밑줄 3~24자',
            ),
            textInputAction: TextInputAction.next,
            autocorrect: false,
            keyboardType: TextInputType.visiblePassword,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
              LengthLimitingTextInputFormatter(24),
            ],
            autofillHints: const [AutofillHints.username],
          ),
          const SizedBox(height: 4),
          Text(
            '이메일 주소 없이 아이디만으로 가입됩니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: '비밀번호 (6자 이상)'),
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordConfirmController,
            decoration: const InputDecoration(labelText: '비밀번호 확인'),
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) {
              if (!loading) onSignUp();
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: loading ? null : onSignUp,
            child: Text(loading ? '처리 중…' : '가입하기'),
          ),
        ],
      ),
    );
  }
}
