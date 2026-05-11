import 'package:flutter/material.dart';

/// 로그인: 아이디·이메일 + 비밀번호 + 버튼.
class LoginIdentityFormSection extends StatelessWidget {
  const LoginIdentityFormSection({
    super.key,
    required this.identityController,
    required this.passwordController,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController identityController;
  final TextEditingController passwordController;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: identityController,
            decoration: const InputDecoration(
              labelText: '아이디 또는 이메일',
              hintText: '예: hello_01',
              border: OutlineInputBorder(),
              helperText: '아이디만 입력해도 됩니다.',
            ),
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [
              AutofillHints.username,
              AutofillHints.email,
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(
              labelText: '비밀번호',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) {
              if (!loading) onSubmit();
            },
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: loading ? null : onSubmit,
            child: Text(loading ? '처리 중…' : '로그인'),
          ),
        ],
      ),
    );
  }
}
