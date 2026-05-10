import 'package:flutter/foundation.dart' show kIsWeb;

/// Supabase `signInWithOAuth`의 [redirectTo].
///
/// 대시보드 **Authentication → URL configuration**에 동일한 origin(및 모바일 딥링크)을
/// **Redirect URLs**에 등록해야 합니다. `flutter run -d chrome` 시 포트가 바뀌면
/// 그 origin도 추가해야 합니다.
abstract final class AuthRedirectConfig {
  static String oauthRedirectUri() {
    if (kIsWeb) {
      return Uri.base.origin;
    }
    // 네이티브 OAuth 시 AndroidManifest / iOS URL Types와 맞춰 등록하세요.
    return 'studyup://auth-callback';
  }
}
