import 'package:flutter/widgets.dart';

/// 로그인·회원가입 입력칸에서 공통으로 쓰는 자동완성 반영·검증.
abstract final class AuthFieldUtils {
  static Future<void> commitAutofill() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  static String? validateEmailPassword(String email, String password) {
    final e = email.trim();
    final p = password.trim();
    if (e.isEmpty || p.isEmpty) {
      return '이메일과 비밀번호를 모두 입력해 주세요.';
    }
    if (p.length < 6) {
      return '비밀번호는 6자 이상이어야 합니다.';
    }
    if (!e.contains('@')) {
      return '이메일 주소 형식을 확인해 주세요.';
    }
    return null;
  }
}
