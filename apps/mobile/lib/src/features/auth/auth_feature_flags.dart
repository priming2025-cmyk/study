/// 인증 UI·기능 토글 (소셜은 Supabase Providers 설정 후 켜기).
abstract final class AuthFeatureFlags {
  /// `false`: 카카오·네이버·구글 줄을 숨기고 아이디/이메일 폼만 즉시 표시.
  /// `true`(기본): 참고 UI처럼 소셜 버튼 노출 (대시보드에 Provider·Redirect URL 필요).
  static const bool socialLoginUiEnabled = true;
}
