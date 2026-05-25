// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_litert/src/web/js_interop/litertjs_bindings.dart'
    show isLiteRtReady, liteRtLoadError;

/// 웹(Safari·Chrome) 전역 [FaceDetector] — 한 번만 초기화하고 재사용.
///
/// ### iPhone Safari 최적화
/// - `auto` 가속기를 먼저 시도: Safari 17+(iOS 17+, 아이폰 13+)는 WebGPU 사용 → 수 초 내 준비
/// - WebGPU 불가 기기(구형 iPhone)는 `wasm` 폴백 → 30~60초 소요
/// - LiteRT 준비를 기다리지 않고 [FaceDetector.create] 를 즉시 시도
///   (패키지 내부 auto-loader가 LiteRT를 병렬로 로드)
final class WebFaceDetectorHolder {
  WebFaceDetectorHolder._();
  static final WebFaceDetectorHolder instance = WebFaceDetectorHolder._();

  FaceDetector? _detector;
  Future<FaceDetector?>? _initFuture;

  FaceDetector? get detector =>
      (_detector != null && _detector!.isReady) ? _detector : null;

  bool get isReady => detector != null;

  /// iPhone · iPad · iPod 여부 (userAgent 기반).
  static bool get isMobileSafari {
    final ua = html.window.navigator.userAgent.toLowerCase();
    return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  }

  /// Safari 17+(iOS 17+) 이상인지 — `navigator.gpu` 존재 여부로 WebGPU 지원 확인.
  static bool get supportsWebGpu {
    try {
      return js_util.hasProperty(html.window.navigator, 'gpu');
    } catch (_) {
      return false;
    }
  }

  Future<void> warmUp() => _getOrCreate();
  Future<FaceDetector?> acquire() => _getOrCreate();

  Future<FaceDetector?> _getOrCreate() async {
    final existing = _detector;
    if (existing != null && existing.isReady) return existing;
    _initFuture ??= _initWithRetry();
    final result = await _initFuture!;
    if (result == null) _initFuture = null;
    return result;
  }

  void scheduleRetry() {
    _initFuture = null;
    final d = _detector;
    _detector = null;
    if (d != null) unawaited(d.dispose().catchError((_) {}));
  }

  Future<void> disposeAll() async {
    _initFuture = null;
    final d = _detector;
    _detector = null;
    if (d == null) return;
    try {
      await d.dispose();
    } catch (e) {
      debugPrint('[WebFaceDetector] dispose: $e');
    }
  }

  // ── 초기화 ─────────────────────────────────────────────────────────────────

  /// LiteRT가 이미 준비됐으면 즉시 반환.
  /// 아직 로드 중이라면 최대 [timeout] 만큼만 기다리고 포기 (FaceDetector.create가
  /// 내부적으로 auto-loader를 재실행하므로 여기서 막힐 필요 없음).
  Future<void> _waitLiteRtShort() async {
    if (isLiteRtReady()) return;
    final completer = Completer<void>();
    void onEvent(html.Event _) {
      if (!completer.isCompleted) completer.complete();
    }
    html.window.addEventListener('litert-ready', onEvent);
    try {
      await completer.future.timeout(const Duration(seconds: 12));
    } on TimeoutException {
      // 짧게 기다렸다가 바로 FaceDetector.create 시도
    } finally {
      html.window.removeEventListener('litert-ready', onEvent);
    }
    final err = liteRtLoadError();
    if (err != null) debugPrint('[WebFaceDetector] page LiteRT error: $err');
  }

  Future<FaceDetector?> _tryCreate(String accel, Duration timeout) async {
    try {
      final d = await FaceDetector.create(
        model: FaceDetectionModel.frontCamera,
        liteRtAccelerator: accel,
      ).timeout(timeout);
      if (d.isReady) return d;
      try { await d.dispose(); } catch (_) {}
    } catch (e) {
      debugPrint('[WebFaceDetector] $accel: $e');
    }
    return null;
  }

  Future<FaceDetector?> _initWithRetry() async {
    final mobile = isMobileSafari;
    final hasGpu = supportsWebGpu;
    debugPrint('[WebFaceDetector] mobile=$mobile hasGpu=$hasGpu');

    // LiteRT 로딩을 최대 12초만 기다린 뒤 바로 시도
    await _waitLiteRtShort();

    // ── 시도 순서 ────────────────────────────────────────────────────────────
    // auto  = WebGPU 우선 (iPhone Safari 17+/iOS 17+ → 수 초)
    //         WebGPU 없으면 내부적으로 WASM 폴백
    // wasm  = 구형 iPhone 폴백 (느리지만 확실)
    final List<(String, Duration)> attempts;
    if (mobile && hasGpu) {
      attempts = [
        ('auto', const Duration(seconds: 18)),
        ('auto', const Duration(seconds: 22)),
        ('wasm', const Duration(seconds: 50)),
      ];
    } else if (mobile) {
      attempts = [
        ('wasm', const Duration(seconds: 45)),
        ('wasm', const Duration(seconds: 50)),
      ];
    } else {
      attempts = [
        ('auto', const Duration(seconds: 15)),
        ('wasm', const Duration(seconds: 20)),
      ];
    }

    for (var i = 0; i < attempts.length; i++) {
      final (accel, timeout) = attempts[i];
      if (i > 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!isLiteRtReady()) await _waitLiteRtShort();
      }
      final d = await _tryCreate(accel, timeout);
      if (d != null) {
        _detector = d;
        debugPrint('[WebFaceDetector] ready accel=$accel mobile=$mobile');
        return d;
      }
    }
    return null;
  }
}
