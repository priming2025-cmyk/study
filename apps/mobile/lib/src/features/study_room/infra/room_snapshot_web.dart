// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:typed_data';

import '../../session/infra/web_shared_camera.dart';

/// 웹: [WebSharedCamera] 공유 스트림에서 JPEG 스냅샷 (2번째 getUserMedia 없음).
class RoomSnapshot {
  bool _initialized = false;

  Future<void> initialize() async {
    try {
      final stream = await WebSharedCamera.instance.acquire();
      _initialized = stream != null;
    } catch (_) {
      _initialized = false;
    }
  }

  Future<Uint8List?> capture() async {
    if (!_initialized) return null;
    return WebSharedCamera.instance.captureJpeg(maxDim: 320, quality: 0.72);
  }

  Future<void> dispose() async {
    WebSharedCamera.instance.release();
    _initialized = false;
  }
}
