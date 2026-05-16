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
      _holders > 0 &&
      _sensor.controller != null &&
      (_sensor.controller?.value.isInitialized ?? false);

  Stream<AttentionSignals> get stream => _sensor.stream;

  CameraController? get controller => _sensor.controller;

  int get previewGeneration => _sensor.previewGeneration;

  /// 카메라를 켭니다. 이미 다른 홀더가 켜 둔 경우 스트림만 공유합니다.
  Future<void> acquire({
    required CameraDescription camera,
    required bool Function() appInForeground,
  }) async {
    if (_holders == 0) {
      await _sensor.start(camera: camera, appInForeground: appInForeground);
    }
    _holders++;
  }

  /// 홀더를 하나 줄입니다. 마지막 홀더면 카메라를 완전히 끕니다.
  Future<void> release() async {
    if (_holders <= 0) return;
    _holders--;
    if (_holders == 0) {
      await _sensor.stop();
    }
  }

  /// 세션 탭 이탈 시: 카메라는 유지하고 구독만 끊을 때 사용 ([release] 호출 금지).
  Future<void> forceStop() async {
    _holders = 0;
    await _sensor.stop();
  }
}
