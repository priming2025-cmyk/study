import 'dart:typed_data';

import 'package:camera/camera.dart';

/// 네이티브(iOS·Android 등): camera 패키지로 스냅샷을 캡처합니다.
class RoomSnapshot {
  CameraController? _controller;
  bool _initialized = false;

  Future<void> initialize() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return;
      final front = cams.where((c) => c.lensDirection == CameraLensDirection.front).toList();
      final cam = front.isNotEmpty ? front.first : cams.first;
      _controller = CameraController(cam, ResolutionPreset.low, enableAudio: false);
      await _controller!.initialize();
      _initialized = true;
    } catch (_) {}
  }

  /// JPEG 바이트를 반환합니다. 실패하면 null.
  Future<Uint8List?> capture() async {
    if (!_initialized || _controller == null) return null;
    try {
      final xfile = await _controller!.takePicture();
      return await xfile.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    try { await _controller?.dispose(); } catch (_) {}
    _controller = null;
    _initialized = false;
  }
}
