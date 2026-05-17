import 'dart:async';

import 'web_face_detector_holder.dart';

/// Vercel 웹: 첫 화면에서 WASM 얼굴 엔진을 미리 로드합니다.
Future<void> warmUpWebAttentionStack() async {
  unawaited(WebFaceDetectorHolder.instance.warmUp());
}
