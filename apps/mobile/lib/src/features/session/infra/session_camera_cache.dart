import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// 앱 생명 주기 동안 카메라 목록을 한 번만 열거해,
/// 세션·스터디방 진입마다 `availableCameras()`가 반복 호출되며 권한/초기화가 겹치는 것을 줄입니다.
abstract final class SessionCameraCache {
  static CameraDescription? _front;
  static bool _enumerated = false;

  static Future<CameraDescription?> getFrontOrDefault() async {
    if (_enumerated) return _front;
    _enumerated = true;
    try {
      final cams = await availableCameras();
      final front =
          cams.where((c) => c.lensDirection == CameraLensDirection.front).toList();
      _front =
          front.isNotEmpty ? front.first : (cams.isNotEmpty ? cams.first : null);
    } catch (e) {
      debugPrint('[SessionCameraCache] availableCameras failed: $e');
      _front = null;
    }
    return _front;
  }

  /// 테스트 등에서만 사용.
  static void resetForTest() {
    _front = null;
    _enumerated = false;
  }
}
