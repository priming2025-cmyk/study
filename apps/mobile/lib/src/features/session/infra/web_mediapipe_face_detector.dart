// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert' show jsonDecode;
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:math' as math;

import '../domain/attention_signals.dart';

/// iPhone Safari 전용 MediaPipe FaceLandmarker 인터랍.
///
/// - `index.html`에서 `window.mpFaceLandmarker`와 `window.mpDetectFaceLandmarks`
///   를 초기화한 뒤 이 클래스가 사용합니다.
/// - WebGL GPU 추론 → iPhone에서 **10~15 초** 내 준비 (LiteRT WASM 대비 훨씬 빠름).
/// - `detectFromVideo`는 동기 JS 호출 후 `AttentionSignals`를 즉시 반환합니다.
final class WebMediaPipeFaceDetector {
  const WebMediaPipeFaceDetector._();

  // EAR 계산용 눈 랜드마크 인덱스 (MediaPipe face mesh 호환)
  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  // ── 준비 상태 ────────────────────────────────────────────────────────────

  /// MediaPipe가 성공적으로 초기화되었는지 여부.
  static bool get isReady {
    try {
      return js_util.getProperty<dynamic>(html.window, 'mpFaceReady') == true;
    } catch (_) {
      return false;
    }
  }

  /// MediaPipe 초기화가 완료(성공·실패 모두)될 때까지 대기.
  /// [timeout] 안에 완료되지 않으면 그냥 반환합니다.
  static Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (isReady) return;
    // 이미 실패 확정이면 즉시 반환
    final ready = js_util.getProperty<dynamic>(html.window, 'mpFaceReady');
    if (ready == false) return;

    final completer = Completer<void>();
    void onEvent(html.Event _) {
      if (!completer.isCompleted) completer.complete();
    }
    html.window.addEventListener('mediapipe-ready', onEvent);
    try {
      await completer.future.timeout(timeout);
    } on TimeoutException {
      // 타임아웃 → 나중에 재시도
    } finally {
      html.window.removeEventListener('mediapipe-ready', onEvent);
    }
  }

  // ── 감지 ────────────────────────────────────────────────────────────────

  /// [videoEl] 프레임에서 얼굴을 감지하고 [AttentionSignals]로 변환합니다.
  /// MediaPipe가 준비되지 않았거나 오류가 발생하면 `null`을 반환합니다.
  static AttentionSignals? detectFromVideo(
    html.VideoElement videoEl,
    bool inForeground,
  ) {
    try {
      final jsonStr = js_util.callMethod<dynamic>(
        html.window,
        'mpDetectFaceLandmarks',
        [videoEl],
      );
      if (jsonStr == null) return null;

      final data = jsonDecode(jsonStr as String) as Map<String, dynamic>;
      final faceCount = (data['n'] as num).toInt();

      if (faceCount == 0) {
        return AttentionSignals(
          facePresent: false,
          multiFace: false,
          appInForeground: inForeground,
        );
      }

      final pts = data['pts'] as Map<String, dynamic>;

      final earL = _ear(pts, _eyeL);
      final earR = _ear(pts, _eyeR);
      final blink = earL < 0.2 && earR < 0.2;
      final pose = _headPose(pts);

      return AttentionSignals(
        facePresent: true,
        multiFace: faceCount > 1,
        appInForeground: inForeground,
        earLeft: earL,
        earRight: earR,
        headYaw: pose.$1,
        headPitch: pose.$2,
        blinkFrame: blink,
      );
    } catch (_) {
      return null;
    }
  }

  // ── 내부 계산 ─────────────────────────────────────────────────────────

  static double _ear(Map<String, dynamic> pts, List<int> idx) {
    try {
      // EAR = (|p1-p5| + |p2-p4|) / (2 × |p0-p3|)
      final v1 = _d(pts, idx[1], idx[5]);
      final v2 = _d(pts, idx[2], idx[4]);
      final h = _d(pts, idx[0], idx[3]);
      if (h < 1e-6) return 0.28;
      return (v1 + v2) / (2.0 * h);
    } catch (_) {
      return 0.28; // 기본값: 눈 뜬 상태
    }
  }

  static double _d(Map<String, dynamic> pts, int a, int b) {
    final pa = pts['$a'] as Map<String, dynamic>;
    final pb = pts['$b'] as Map<String, dynamic>;
    final dx = (pa['x'] as num) - (pb['x'] as num);
    final dy = (pa['y'] as num) - (pb['y'] as num);
    return math.sqrt(dx * dx + dy * dy);
  }

  static (double, double) _headPose(Map<String, dynamic> pts) {
    try {
      // 코끝(1), 좌안 외안각(226), 우안 외안각(446), 턱(152)
      if (!pts.containsKey('1') || !pts.containsKey('226') ||
          !pts.containsKey('446') || !pts.containsKey('152')) {
        return (0.0, 0.0);
      }
      final nose = pts['1'] as Map<String, dynamic>;
      final eyeL = pts['226'] as Map<String, dynamic>;
      final eyeR = pts['446'] as Map<String, dynamic>;
      final chin = pts['152'] as Map<String, dynamic>;

      final eyeCx = ((eyeL['x'] as num) + (eyeR['x'] as num)) / 2;
      final eyeCy = ((eyeL['y'] as num) + (eyeR['y'] as num)) / 2;
      final eyeWidth = ((eyeR['x'] as num) - (eyeL['x'] as num)).abs();
      if (eyeWidth < 1e-6) return (0.0, 0.0);

      final yaw = ((nose['x'] as num) - eyeCx) / eyeWidth * 90.0;

      final faceH =
          ((chin['y'] as num) - eyeCy).abs().clamp(1e-6, double.infinity);
      final pitch = (((nose['y'] as num) - eyeCy) / faceH - 0.35) * 120.0;

      return (yaw, pitch);
    } catch (_) {
      return (0.0, 0.0);
    }
  }
}
