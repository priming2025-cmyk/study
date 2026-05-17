import 'dart:async';

import 'package:flutter/foundation.dart';

import 'web_face_detector_holder.dart';

/// Vercel 웹: 얼굴 엔진 예열 (LiteRT는 index.html에서 미리 로드).
Future<void> warmUpWebAttentionStack() async {
  try {
    await WebFaceDetectorHolder.instance.warmUp();
  } catch (e, st) {
    debugPrint('[warmUpWebAttentionStack] $e\n$st');
  }
}
