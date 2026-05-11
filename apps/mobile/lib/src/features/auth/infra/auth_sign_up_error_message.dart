import 'package:supabase_flutter/supabase_flutter.dart';

/// 회원가입 API 오류를 사용자 안내로 풉니다.
abstract final class AuthSignUpErrorMessage {
  static String forSignUp(AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    if (code == 'over_email_send_rate_limit') {
      return '인증 메일 발송 한도에 걸렸어요. 잠시 후 다시 시도해 주세요.\n'
          '(개발·운영 환경에서는 이메일 인증 발송을 줄이면 완화되는 경우가 많아요.)';
    }
    if (code == 'over_request_rate_limit') {
      return '요청이 너무 잦습니다. 1~2분 뒤에 다시 가입해 주세요.';
    }
    final msg = e.message.toLowerCase();
    if (msg.contains('rate limit') && msg.contains('email')) {
      return '이메일 관련 요청이 너무 많았어요. 잠시 뒤 다시 시도해 주세요.';
    }
    return e.message;
  }
}
