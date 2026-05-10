import 'package:flutter/material.dart';

/// 회원가입 화면의 이메일·역할 폼 (소셜 가입과 구분).
class SignUpEmailFormCard extends StatelessWidget {
  const SignUpEmailFormCard({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.role,
    required this.onRoleChanged,
    required this.loading,
    required this.onSignUp,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
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
            controller: emailController,
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
            controller: passwordController,
            decoration: const InputDecoration(labelText: '비밀번호 (6자 이상)'),
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
