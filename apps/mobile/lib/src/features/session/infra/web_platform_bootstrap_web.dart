import 'dart:async';

import 'package:flutter/foundation.dart';

import 'web_face_detector_holder.dart';

/// 웹: 앱 시작 직후 얼굴 엔진 예열 (iPhone Safari는 최초 로드가 길 수 있음).
Future<void> warmUpWebAttentionStack() async {
  try {
    await WebFaceDetectorHolder.instance
        .warmUp()
        .timeout(const Duration(seconds: 90));
  } on TimeoutException {
    debugPrint('[warmUpWebAttentionStack] timeout (계속 백그라운드 재시도)');
    unawaited(WebFaceDetectorHolder.instance.warmUp());
  } catch (e, st) {
    debugPrint('[warmUpWebAttentionStack] $e\n$st');
    WebFaceDetectorHolder.instance.scheduleRetry();
    unawaited(WebFaceDetectorHolder.instance.warmUp());
  }
}
