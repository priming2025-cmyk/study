import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase에 등록한 provider id와 **문자 하나까지** 동일해야 합니다.
/// 네이버는 대개 Custom OIDC로 추가하며, 대시보드의 Provider ID가 `naver`가
/// 아니면 이 파일의 `naver` 상수만 대시보드 ID에 맞게 바꿉니다.
abstract final class StudyUpOAuth {
  static const naver = OAuthProvider('naver');
}
