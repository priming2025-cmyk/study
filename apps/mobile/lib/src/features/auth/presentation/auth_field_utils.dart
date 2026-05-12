import 'package:flutter/widgets.dart';

abstract final class AuthFieldUtils {
  static Future<void> commitAutofill() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  static final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');

  static String? validateEmail(String raw) {
    final e = raw.trim();
    if (e.isEmpty) return '이메일을 입력해 주세요.';
    if (!_emailRe.hasMatch(e)) return '이메일 형식이 올바르지 않아요. (예: user@example.com)';
    return null;
  }

  static String? validatePassword(String raw) {
    final p = raw.trim();
    if (p.isEmpty) return '비밀번호를 입력해 주세요.';
    if (p.length < 6) return '비밀번호는 6자 이상이어야 합니다.';
    return null;
  }

  static String? validateLogin(String emailRaw, String passwordRaw) {
    return validateEmail(emailRaw) ?? validatePassword(passwordRaw);
  }

  static String? validateSignUp(
    String emailRaw,
    String passwordRaw,
    String confirmRaw,
  ) {
    final emailErr = validateEmail(emailRaw);
    if (emailErr != null) return emailErr;
    final pwErr = validatePassword(passwordRaw);
    if (pwErr != null) return pwErr;
    if (confirmRaw.trim().isEmpty) return '비밀번호 확인을 입력해 주세요.';
    if (passwordRaw.trim() != confirmRaw.trim()) {
      return '비밀번호가 일치하지 않아요. 다시 확인해 주세요.';
    }
    return null;
  }
}
