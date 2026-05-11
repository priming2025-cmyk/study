import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;

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
              hintText: '예: hello_12',
              border: OutlineInputBorder(),
              helperText: '영문 소문자·숫자·_ 만 가능. 안 써지면 키보드를 영문(한영)으로 바꿔 주세요.',
              helperMaxLines: 2,
            ),
            textInputAction: TextInputAction.next,
            autocorrect: false,
            keyboardType: TextInputType.text,
            inputFormatters: [
              LengthLimitingTextInputFormatter(24),
            ],
            autofillHints: const [AutofillHints.username],
          ),
          const SizedBox(height: 4),
          Text(
            '이메일 없이 아이디만으로 가입됩니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(
              labelText: '비밀번호 (6자 이상)',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordConfirmController,
            decoration: const InputDecoration(
              labelText: '비밀번호 확인',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) {
              if (!loading) onSignUp();
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            onPressed: loading ? null : onSignUp,
            child: Text(loading ? '처리 중…' : '가입하기'),
          ),
        ],
      ),
    );
  }
}
