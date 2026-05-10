import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase에 등록한 provider id와 동일해야 합니다.
/// 네이버는 프로젝트마다 Custom OIDC slug가 다를 수 있어 `naver`가 아니면
/// 대시보드 값에 맞게 수정하세요.
abstract final class StudyUpOAuth {
  static const naver = OAuthProvider('naver');
}
