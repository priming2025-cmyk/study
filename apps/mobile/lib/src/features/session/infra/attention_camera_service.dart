import 'package:camera/camera.dart';

import '../domain/attention_signals.dart';
import 'face_attention_sensor.dart';

/// 앱 전체 **단일** 전면 카메라·얼굴 센서 (공부 세션 ↔ 셋터디방 이중 점유 방지).
final class AttentionCameraService {
  AttentionCameraService._();
  static final AttentionCameraService instance = AttentionCameraService._();

  final FaceAttentionSensor _sensor = FaceAttentionSensor();
  int _holders = 0;

  FaceAttentionSensor get sensor => _sensor;

  bool get hasActiveCamera =>
      _sensor.isCameraReady &&
      _sensor.controller != null &&
      (_sensor.controller?.value.isInitialized ?? false);

  /// 최근 프레임에서 유효한 얼굴 검출이 있었는지 (iOS 오검·카메라 미준비 시 집중 집계 차단).
  bool get hasRecentValidSample => _sensor.hasRecentValidSample;

  Stream<AttentionSignals> get stream => _sensor.stream;

  CameraController? get controller => _sensor.controller;

  int get previewGeneration => _sensor.previewGeneration;

  Future<void> acquire({
    required CameraDescription camera,
    required bool Function() appInForeground,
  }) async {
    if (!hasActiveCamera) {
      if (_holders > 0) {
        await forceStop();
      }
      await _sensor.start(camera: camera, appInForeground: appInForeground);
    }
    _holders++;
  }

  Future<void> release() async {
    if (_holders <= 0) return;
    _holders--;
    if (_holders <= 0) {
      _holders = 0;
      await _sensor.stop();
    }
  }

  Future<void> forceStop() async {
    _holders = 0;
    await _sensor.stop();
  }
}
