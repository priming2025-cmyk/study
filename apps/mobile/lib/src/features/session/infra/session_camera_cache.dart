import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// 앱 생명 주기 동안 카메라 목록을 캐시.
///
/// - **iOS**: 매번 `availableCameras()`를 새로 호출합니다. 이전 세션에서
///   AVCaptureSession이 닫힌 직후 캐시된 [CameraDescription]을 그대로 쓰면
///   2회차 카메라가 안 열리는 케이스가 자주 보고됩니다.
/// - **그 외 플랫폼**: 1회 캐시.
abstract final class SessionCameraCache {
  static CameraDescription? _front;
  static bool _enumerated = false;

  static Future<CameraDescription?> getFrontOrDefault() async {
    final cacheValid =
        _enumerated && !(kIsWeb == false && Platform.isIOS);
    if (cacheValid) return _front;
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
