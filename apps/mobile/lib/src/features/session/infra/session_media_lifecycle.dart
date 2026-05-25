import 'package:flutter/foundation.dart' show kIsWeb;

import 'attention_camera_service.dart';
import 'web_camera.dart';
import 'web_face_detector_holder.dart';

/// 세션 종료·방 퇴장 직후: 스트림을 잠시 유지(약 10분)해 재허용 팝업을 줄입니다.
Future<void> releaseSharedCameraMedia() async {
  if (kIsWeb) {
    WebSharedCamera.instance.release();
  } else {
    await AttentionCameraService.instance.release();
  }
}

/// 수동 새로고침 실패·앱 종료 등 — 카메라 트랙을 즉시 끕니다.
Future<void> teardownSharedCameraMedia({bool disposeFaceEngine = false}) async {
  if (kIsWeb) {
    WebSharedCamera.instance.forceRelease();
    if (disposeFaceEngine) {
      await WebFaceDetectorHolder.instance.disposeAll();
    }
  } else {
    await AttentionCameraService.instance.forceStop();
  }
}
