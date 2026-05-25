import 'package:flutter/foundation.dart' show kIsWeb;

import 'attention_camera_service.dart';
import 'web_camera.dart';
import 'web_face_detector_holder.dart';

/// 스터디방 퇴장·세션 종료 시 카메라·분석 엔진을 완전히 해제합니다.
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
