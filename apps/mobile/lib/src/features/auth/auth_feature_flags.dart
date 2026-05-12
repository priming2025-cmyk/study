/// 인증 UI·기능 토글.
abstract final class AuthFeatureFlags {
  /// `false`: 카카오·네이버·구글 버튼 숨김 (이메일 로그인만 표시).
  /// `true`: 소셜 버튼 노출 (Supabase 대시보드에 Provider 설정 필요).
  static const bool socialLoginUiEnabled = false;

  /// `true`: 회원가입 진입 활성.
  static const bool signUpFlowEnabled = true;

  /// `true` 이고 **디버그 빌드일 때만** 로그인 없이 앱 첫 화면(홈)으로 진입 가능.
  /// 실제 로그인 테스트를 위해 false 로 설정합니다.
  static const bool devBypassAuthGate = false;
}
