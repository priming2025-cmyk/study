// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';

/// 웹(Safari·Chrome) 전역 [FaceDetector] — 한 번만 초기화하고 재사용.
///
/// LiteRT.js는 [web/index.html] 에서 페이지 로드 시 미리 받습니다.
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

  static bool _pageLiteRtReady() {
    try {
      final dynamic w = html.window;
      return w.LiteRtReady == true;
    } catch (_) {
      return false;
    }
  }

  Future<FaceDetector?> _initWithRetry() async {
    if (!_pageLiteRtReady()) {
      final done = Completer<void>();
      void onReady(html.Event _) {
        if (!done.isCompleted) done.complete();
      }

      html.window.addEventListener('litert-ready', onReady);
      try {
        await done.future.timeout(
          const Duration(seconds: 90),
          onTimeout: () {},
        );
      } finally {
        html.window.removeEventListener('litert-ready', onReady);
      }
    }

    final attempts = _isMobileSafari
        ? [
            ('wasm', 0),
            ('wasm', 1500),
            ('wasm', 3500),
          ]
        : [
            ('wasm', 0),
            ('auto', 800),
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
