/// 인증 UI·기능 토글 (소셜은 Supabase Providers 설정 후 켜기).
abstract final class AuthFeatureFlags {
  /// `false`: 카카오·네이버·구글 줄을 숨기고 아이디/이메일 폼만 즉시 표시.
  /// `true`(기본): 참고 UI처럼 소셜 버튼 노출 (대시보드에 Provider·Redirect URL 필요).
  static const bool socialLoginUiEnabled = true;

  /// `false`: 회원가입 진입(로그인의 「회원가입」·`/signup`) 비활성. 라우트는 `/` 로 돌립니다.
  /// 시험용으로 끌 때는 `false`, 출시 전에 `true` 로 바꿉니다.
  static const bool signUpFlowEnabled = false;

  /// `true` 이고 **디버그 빌드일 때만** 로그인 없이 앱 첫 화면(홈)으로 진입 가능.
  /// 릴리스(`flutter build`)에서는 무시되며 반드시 로그인합니다.
  static const bool devBypassAuthGate = true;
}
