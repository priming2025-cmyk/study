// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_litert/src/web/js_interop/litertjs_bindings.dart'
    show configureLiteRtLoader, isLiteRtReady, liteRtLoadError, waitForLiteRt;

/// 웹(Safari·Chrome) 전역 [FaceDetector] — 한 번만 초기화하고 재사용.
final class WebFaceDetectorHolder {
  WebFaceDetectorHolder._();
  static final WebFaceDetectorHolder instance = WebFaceDetectorHolder._();

  FaceDetector? _detector;
  Future<FaceDetector?>? _initFuture;

  static const _cdnBase = 'https://cdn.jsdelivr.net/npm/@litertjs/core@2.4.0';

  FaceDetector? get detector =>
      (_detector != null && _detector!.isReady) ? _detector : null;

  bool get isReady => detector != null;

  static bool get isMobileSafari {
    final ua = html.window.navigator.userAgent.toLowerCase();
    return ua.contains('iphone') ||
        ua.contains('ipad') ||
        ua.contains('ipod') ||
        (ua.contains('mobile') && ua.contains('safari'));
  }

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
    final d = _detector;
    _detector = null;
    if (d != null) {
      unawaited(d.dispose().catchError((_) {}));
    }
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

  Future<void> _waitLiteRtReady({required Duration timeout}) async {
    if (isLiteRtReady()) return;

    configureLiteRtLoader(
      moduleUrl: '$_cdnBase/+esm',
      wasmUrl: '$_cdnBase/wasm/litert_wasm_internal.js',
      autoLoad: true,
    );

    try {
      await waitForLiteRt(timeout: timeout);
      if (isLiteRtReady()) return;
    } catch (e) {
      debugPrint('[WebFaceDetector] waitForLiteRt: $e');
      final err = liteRtLoadError();
      if (err != null) debugPrint('[WebFaceDetector] LiteRT page error: $err');
    }

    final completer = Completer<void>();
    void onEvent(html.Event _) {
      if (!completer.isCompleted) completer.complete();
    }

    html.window.addEventListener('litert-ready', onEvent);
    try {
      await completer.future.timeout(timeout);
    } on TimeoutException {
      debugPrint('[WebFaceDetector] litert-ready event timeout');
    } finally {
      html.window.removeEventListener('litert-ready', onEvent);
    }
  }

  Future<FaceDetector?> _tryCreate(String accel) async {
    final d = await FaceDetector.create(
      model: FaceDetectionModel.frontCamera,
      liteRtAccelerator: accel,
    );
    if (d.isReady) return d;
    try {
      await d.dispose();
    } catch (_) {}
    return null;
  }

  Future<FaceDetector?> _initWithRetry() async {
    final mobile = isMobileSafari;
    final liteRtTimeout =
        mobile ? const Duration(seconds: 120) : const Duration(seconds: 50);

    await _waitLiteRtReady(timeout: liteRtTimeout);

    if (!isLiteRtReady()) {
      debugPrint('[WebFaceDetector] LiteRT not ready after wait');
    }

    final accelerators = mobile
        ? <String>['wasm', 'wasm', 'webgl', 'cpu', 'auto', 'wasm']
        : <String>['wasm', 'webgl', 'auto', 'wasm'];

    for (var i = 0; i < accelerators.length; i++) {
      final accel = accelerators[i];
      if (i > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: mobile ? 1200 : 350),
        );
      }
      try {
        final d = await _tryCreate(accel);
        if (d != null) {
          _detector = d;
          debugPrint('[WebFaceDetector] ready ($accel, mobile=$mobile)');
          return d;
        }
      } catch (e, st) {
        debugPrint('[WebFaceDetector] init #$i ($accel): $e\n$st');
      }
    }

    return null;
  }
}
