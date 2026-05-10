import 'package:flutter_dotenv/flutter_dotenv.dart';

/// `.env`의 Supabase 설정 (런타임에만 읽음).
///
/// **웹 PKCE·소셜 로그인**: 대시보드 Authentication → URL configuration 에서
/// `Site URL`과 `Redirect URLs`에 로컬/배포 **origin**(예: `http://localhost:53426`)을 넣어야
/// 이메일 링크·카카오/네이버/구글 OAuth가 동작합니다. `flutter run -d chrome` 포트가 바뀔 때마다
/// 해당 origin을 Redirect URLs에 추가하거나, 개발용으로 허용 범위를 넓혀 주세요.
class SupabaseConfig {
  static String get url => (dotenv.env['SUPABASE_URL'] ?? '').trim();

  static String get anonKey => (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// `.env.example`을 그대로 쓴 것처럼 보일 때(실수 방지).
  static bool get looksLikeTemplate =>
      url.contains('YOUR_PROJECT') || anonKey.contains('YOUR_ANON_KEY');

  /// 앱 기동 전 호출. 비어 있으면 즉시 실패해 원인을 분명히 합니다.
  static void validateForRun() {
    if (!isConfigured) {
      throw StateError(
        'Supabase 설정이 없습니다. apps/mobile/.env 에 SUPABASE_URL 과 '
        'SUPABASE_ANON_KEY 를 채운 뒤 다시 실행해 주세요.',
      );
    }
  }
}
