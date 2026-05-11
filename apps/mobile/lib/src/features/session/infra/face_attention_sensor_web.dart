import 'dart:async';

import 'package:camera/camera.dart';

import '../domain/attention_signals.dart';

/// 웹(Flutter Web)에서는 TFLite 미지원으로 얼굴 감지를 실행할 수 없습니다.
/// 1초 간격으로 "재실 중"(facePresent: true) 신호를 내보내는 타이머 스텁입니다.
///
/// 사용자에게는 세션 화면에서 "브라우저 모드" 안내를 표시합니다.
class FaceAttentionSensor {
  StreamController<AttentionSignals>? _signals;
  Timer? _timer;
  bool _running = false;

  FaceAttentionSensor();

  Future<void> start({
    CameraDescription? camera,
    required bool Function() appInForeground,
  }) async {
    if (_running) return;
    _running = true;
    _signals = StreamController<AttentionSignals>.broadcast();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _signals?.add(
        AttentionSignals(
          facePresent: true,
          multiFace: false,
          appInForeground: appInForeground(),
        ),
      );
    });
  }

  Stream<AttentionSignals> get stream =>
      _signals?.stream ?? const Stream.empty();

  CameraController? get controller => null;

  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    await _signals?.close();
    _signals = null;
  }
}
