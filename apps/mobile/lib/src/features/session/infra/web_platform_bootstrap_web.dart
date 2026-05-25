import 'dart:async';

import 'package:flutter/foundation.dart';

import 'web_face_detector_holder.dart';

/// 웹: 앱 시작 직후 얼굴 엔진 예열.
/// 빠르게 실패해도 [WebFaceDetectorHolder]가 [acquire] 시점에 재시도하므로 괜찮음.
Future<void> warmUpWebAttentionStack() async {
  try {
    await WebFaceDetectorHolder.instance
        .warmUp()
        .timeout(const Duration(seconds: 30));
  } on TimeoutException {
    debugPrint('[warmUpWebAttentionStack] 타임아웃 → acquire 시점에 재시도');
    unawaited(WebFaceDetectorHolder.instance.warmUp());
  } catch (e, st) {
    debugPrint('[warmUpWebAttentionStack] $e\n$st');
    WebFaceDetectorHolder.instance.scheduleRetry();
    unawaited(WebFaceDetectorHolder.instance.warmUp());
  }
}
