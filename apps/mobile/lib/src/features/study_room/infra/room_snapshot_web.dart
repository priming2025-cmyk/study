// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:typed_data';

import '../../session/infra/web_shared_camera.dart';

/// 웹: 이미 켜진 [WebSharedCamera] 스트림에서만 JPEG 스냅샷 (getUserMedia 추가 호출 없음).
class RoomSnapshot {
  Future<void> initialize() async {}

  Future<Uint8List?> capture() async {
    if (!WebSharedCamera.instance.isStreamReady) return null;
    return WebSharedCamera.instance.captureJpeg(maxDim: 320, quality: 0.72);
  }

  Future<void> dispose() async {}
}
