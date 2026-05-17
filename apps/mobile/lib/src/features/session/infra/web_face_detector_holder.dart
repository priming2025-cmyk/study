// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_litert/src/web/js_interop/litertjs_bindings.dart'
    show isLiteRtReady, liteRtLoadError, waitForLiteRt;

/// 웹(Safari·Chrome) 전역 [FaceDetector] — 한 번만 초기화하고 재사용.
final class WebFaceDetectorHolder {
  WebFaceDetectorHolder._();
  static final WebFaceDetectorHolder instance = WebFaceDetectorHolder._();

  FaceDetector? _detector;
  Future<FaceDetector?>? _initFuture;

  FaceDetector? get detector =>
      (_detector != null && _detector!.isReady) ? _detector : null;

  bool get isReady => detector != null;

  Future<void> warmUp() => _getOrCreate();

  Future<FaceDetector?> acquire() => _getOrCreate();

  Future<FaceDetector?> _getOrCreate() async {
    final existing = _detector;
    if (existing != null && existing.isReady) return existing;
    if (_initFuture != null) return _initFuture!;
    _initFuture = _initWithRetry();
    final result = await _initFuture!;
    if (result == null) {
      _initFuture = null;
    }
    return result;
  }

  void scheduleRetry() {
    _initFuture = null;
  }

  Future<void> disposeAll() async {
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

  static bool get _isMobileSafari {
    final ua = html.window.navigator.userAgent.toLowerCase();
    return ua.contains('iphone') ||
        ua.contains('ipad') ||
        ua.contains('ipod') ||
        (ua.contains('mobile') && ua.contains('safari'));
  }

  Future<FaceDetector?> _initWithRetry() async {
    try {
      await waitForLiteRt(timeout: const Duration(seconds: 60));
    } catch (e) {
      debugPrint('[WebFaceDetector] LiteRT wait: $e');
      final err = liteRtLoadError();
      if (err != null) debugPrint('[WebFaceDetector] LiteRT error: $err');
    }

    if (!isLiteRtReady()) {
      debugPrint('[WebFaceDetector] LiteRT not ready after wait');
    }

    final attempts = _isMobileSafari
        ? [
            ('wasm', 0),
            ('wasm', 2000),
          ]
        : [
            ('wasm', 0),
            ('auto', 600),
          ];

    for (var i = 0; i < attempts.length; i++) {
      final accel = attempts[i].$1;
      final delayMs = attempts[i].$2;
      if (delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      try {
        final d = await FaceDetector.create(
          model: FaceDetectionModel.frontCamera,
          liteRtAccelerator: accel,
        );
        if (!d.isReady) {
          await d.dispose();
          continue;
        }
        _detector = d;
        debugPrint('[WebFaceDetector] ready ($accel)');
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
