import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Premium 영상방(WebRTC): `.env`의 `PREMIUM_VIDEO_ENABLED`가 true/1/on 이면 잠금 해제.
class FeatureFlags {
  static bool get premiumVideoEnabled {
    final raw = (dotenv.env['PREMIUM_VIDEO_ENABLED'] ?? '').trim().toLowerCase();
    return raw == 'true' ||
        raw == '1' ||
        raw == 'yes' ||
        raw == 'on';
  }
}
