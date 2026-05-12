import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// /signup 경로는 /login 으로 통합되었습니다.
/// app.dart 의 redirect 에서 /signup → /login 으로 리디렉션하므로
/// 이 화면은 실질적으로 사용되지 않습니다.
class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('/login');
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
