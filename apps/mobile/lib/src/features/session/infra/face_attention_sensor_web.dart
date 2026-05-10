import 'dart:async';

import 'package:camera/camera.dart';

import '../domain/attention_signals.dart';

/// 웹에서는 ML Kit 카메라 파이프라인 없이 간단히 타이머 기반 신호만 내보냅니다(미리보기 없음).
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

  Stream<AttentionSignals> get stream {
    final s = _signals;
    if (s == null) {
      return const Stream.empty();
    }
    return s.stream;
  }

  CameraController? get controller => null;

  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    await _signals?.close();
    _signals = null;
  }
}
