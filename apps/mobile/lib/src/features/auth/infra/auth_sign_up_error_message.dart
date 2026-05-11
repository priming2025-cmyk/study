import 'package:supabase_flutter/supabase_flutter.dart';

/// 회원가입 API 오류를 사용자 안내로 풉니다.
abstract final class AuthSignUpErrorMessage {
  static String forSignUp(AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    if (code == 'over_email_send_rate_limit') {
      return '이메일 발송 한도에 걸렸습니다. 잠시 후 다시 시도하거나,\n'
          'Supabase 대시보드 → Authentication → Providers → Email 에서 '
          '「Confirm email」을 끄면 인증 메일을 보내지 않아 이 제한이 줄어듭니다.\n'
          '(무료 플랜은 시간당 발송 수 제한이 작습니다.)';
    }
    if (code == 'over_request_rate_limit') {
      return '요청이 너무 잦습니다. 1~2분 뒤에 다시 가입해 주세요.';
    }
    final msg = e.message.toLowerCase();
    if (msg.contains('rate limit') && msg.contains('email')) {
      return '이메일 관련 호출 한도를 넘었습니다. 잠시 기다린 뒤 재시도하거나, '
          '이메일 인증 메일 발송을 끄려면 Confirm email 설정을 확인해 주세요.';
    }
    return e.message;
  }
}
