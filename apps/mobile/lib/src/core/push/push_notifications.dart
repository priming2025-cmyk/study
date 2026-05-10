/// 푸시(FCM 등) 연동은 여기서 초기화·권한을 모읍니다. 현재 MVP는 no-op입니다.
abstract final class PushNotifications {
  static Future<void> initAfterLaunch() async {
    // TODO: firebase_messaging 또는 유사 SDK 연동 시
    // - 권한 요청(iOS/Android 13+)
    // - 토큰을 Supabase user 메타 또는 별도 테이블에 저장
  }
}
