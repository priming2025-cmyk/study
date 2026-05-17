import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';

/// 웹(Safari·Chrome) 전역 [FaceDetector] — 한 번만 초기화하고 재사용.
///
/// iOS Safari는 WebGPU 초기화가 실패하는 경우가 많아 `wasm`으로 재시도합니다.
/// 위젯이 dispose될 때마다 새로 만들면 "already initialized"·메모리 오류가 납니다.
final class WebFaceDetectorHolder {
  WebFaceDetectorHolder._();
  static final WebFaceDetectorHolder instance = WebFaceDetectorHolder._();

  FaceDetector? _detector;
  Future<FaceDetector?>? _initFuture;
  int _holders = 0;

  FaceDetector? get detector =>
      (_detector != null && _detector!.isReady) ? _detector : null;

  /// 분석기를 가져옵니다. 실패 시 null (가짜 facePresent 는 내지 않음).
  Future<FaceDetector?> acquire() {
    _holders++;
    return _getOrCreate();
  }

  Future<FaceDetector?> _getOrCreate() async {
    final existing = _detector;
    if (existing != null && existing.isReady) return existing;
    if (_initFuture != null) {
      return _initFuture!;
    }
    _initFuture = _initWithRetry();
    final result = await _initFuture!;
    if (result == null) {
      _initFuture = null;
    }
    return result;
  }

  void release() {
    if (_holders <= 0) return;
    _holders--;
    if (_holders <= 0) {
      _holders = 0;
      // 페이지를 벗어날 때만 완전 해제 (탭 전환 시 재초기화 부담 감소)
    }
  }

  /// 완전 초기화 (페이지 새로고침 전용).
  Future<void> disposeAll() async {
    _holders = 0;
    _initFuture = null;
    final d = _detector;
    _detector = null;
    if (d != null) {
      try {
        await d.dispose();
      } catch (e) {
        debugPrint('[WebFaceDetector] dispose: $e');
      }
    }
  }

  Future<FaceDetector?> _initWithRetry() async {
    const attempts = [
      ('auto', 0),
      ('wasm', 400),
      ('wasm', 900),
      ('wasm', 1600),
    ];

    for (var i = 0; i < attempts.length; i++) {
      final accel = attempts[i].$1;
      final delayMs = attempts[i].$2;
      if (delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      try {
        final d = FaceDetector();
        await d.initialize(
          model: FaceDetectionModel.frontCamera,
          liteRtAccelerator: accel,
        );
        if (!d.isReady) {
          await d.dispose();
          continue;
        }
        _detector = d;
        debugPrint('[WebFaceDetector] ready (accelerator=$accel)');
        return d;
      } catch (e, st) {
        debugPrint('[WebFaceDetector] init #$i ($accel): $e\n$st');
        try {
          await _detector?.dispose();
        } catch (_) {}
        _detector = null;
      }
    }
    return null;
  }
}
