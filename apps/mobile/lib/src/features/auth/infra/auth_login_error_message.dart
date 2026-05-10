import 'package:supabase_flutter/supabase_flutter.dart';

/// 로그인 실패 시 서버 메시지(영문)·코드를 사용자 안내로 풉니다.
abstract final class AuthLoginErrorMessage {
  static String forSignIn(AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    if (code == 'email_not_confirmed') {
      return '이메일 확인이 필요한 상태입니다.\n'
          '편하게 쓰려면 Supabase → Authentication → Providers → Email 에서 「Confirm email」을 끄세요.\n'
          '켜 두었다면 가입 메일의 인증 링크를 누른 뒤 다시 로그인하세요.';
    }
    final lower = e.message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials')) {
      return '로그인 정보가 다르거나, 이메일 확인이 필요한 설정일 때 같은 메시지가 날 수 있어요.\n'
          '• 이메일·비밀번호 오타 확인\n'
          '• MVP 편의: Authentication → Providers → Email → 「Confirm email」 OFF\n'
          '• 인증 켠 경우: 메일 인증 후 다시 로그인';
    }
    return e.message;
  }
}
