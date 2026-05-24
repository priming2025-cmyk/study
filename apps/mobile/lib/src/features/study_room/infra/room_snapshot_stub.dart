import 'dart:typed_data';

import '../../session/infra/attention_camera_service.dart';

/// 네이티브(iOS·Android): [AttentionCameraService] 단일 카메라에서 JPEG 스냅샷.
/// (별도 CameraController를 열면 실시간 프리뷰와 충돌합니다.)
class RoomSnapshot {
  Future<void> initialize() async {}

  Future<Uint8List?> capture() async {
    return AttentionCameraService.instance.captureSnapshotJpeg();
  }

  Future<void> dispose() async {}
}
