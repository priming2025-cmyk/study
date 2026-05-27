import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 앱 **종료 상태** 친구 DM 푸시(FCM/APNs).
///
/// 기본값은 **꺼짐** — Firebase·APNs 설정 전에도 앱 접속·DM 테스트가 가능합니다.
/// 준비가 끝나면 `apps/mobile/.env` 에 `SETUDY_FCM_ENABLED=true` 로 켭니다.
/// 체크리스트: `apps/mobile/docs/ios.md` §8-A
abstract final class PushFeatureConfig {
  static bool get fcmEnabled {
    final raw = dotenv.env['SETUDY_FCM_ENABLED']?.trim().toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }
}
