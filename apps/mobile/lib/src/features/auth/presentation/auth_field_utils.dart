import 'package:flutter/widgets.dart';

/// Supabase 비밀번호 로그인은 **이메일 형식 문자열**만 받습니다.
/// 사용자에게는 아이디만 받고, 내부에서 `@users.studyup.internal`을 붙여 사용합니다.
/// `@`가 들어 있는 입력은 일반 이메일 계정으로 그대로 씁니다(기존 사용자 호환).
abstract final class AuthFieldUtils {
  static const pseudoEmailDomain = 'users.studyup.internal';

  static Future<void> commitAutofill() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  /// 로그인/가입 요청 시 Supabase에 넘길 `email` 파라미터.
  static String toAuthEmail(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.contains('@')) return t;
    return '${normalizeUsername(t)}@$pseudoEmailDomain';
  }

  static String normalizeUsername(String raw) => raw.trim().toLowerCase();

  static final _usernameChars = RegExp(r'^[a-z0-9_]+$');

  static String? validateUsername(String raw) {
    final u = normalizeUsername(raw);
    if (u.isEmpty) {
      return '아이디를 입력해 주세요.';
    }
    if (u.length < 3 || u.length > 24) {
      return '아이디는 영문 소문자·숫자·밑줄(_) 3~24자입니다.';
    }
    if (!_usernameChars.hasMatch(u)) {
      return '아이디는 영문 소문자, 숫자, 밑줄(_)만 사용할 수 있어요.';
    }
    return null;
  }

  static String? validateLogin(String credentialRaw, String passwordRaw) {
    final c = credentialRaw.trim();
    final p = passwordRaw.trim();
    if (c.isEmpty || p.isEmpty) {
      return '아이디(또는 이메일)와 비밀번호를 입력해 주세요.';
    }
    if (p.length < 6) {
      return '비밀번호는 6자 이상이어야 합니다.';
    }
    if (!c.contains('@')) {
      return validateUsername(c);
    }
    final parts = c.split('@');
    if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
      return '이메일 형식을 확인해 주세요.';
    }
    return null;
  }

  /// 간편 가입: 아이디 + 비밀번호 + 비밀번호 확인.
  static String? validateSimpleSignUp(
    String usernameRaw,
    String passwordRaw,
    String passwordConfirmRaw,
  ) {
    final userErr = validateUsername(usernameRaw);
    if (userErr != null) return userErr;
    final p = passwordRaw.trim();
    final c = passwordConfirmRaw.trim();
    if (p.isEmpty || c.isEmpty) {
      return '비밀번호와 비밀번호 확인을 모두 입력해 주세요.';
    }
    if (p.length < 6) {
      return '비밀번호는 6자 이상이어야 합니다.';
    }
    if (p != c) {
      return '비밀번호가 서로 같지 않습니다. 다시 확인해 주세요.';
    }
    return null;
  }
}
