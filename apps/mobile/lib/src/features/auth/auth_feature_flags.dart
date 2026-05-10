/// 인증 UI·기능 토글 (소셜은 Supabase Providers 설정 후 켜기).
abstract final class AuthFeatureFlags {
  /// `false`: 로그인·회원가입은 이메일+비밀번호만 표시 (Supabase 이메일 테스트용).
  /// 카카오/네이버/구글을 켤 때 `true`로 바꾸고 대시보드에 Client ID/Secret을 넣습니다.
  static const bool socialLoginUiEnabled = false;
}
