import 'dart:math' as math;
import 'dart:typed_data';

import 'package:face_detection_tflite/face_detection_tflite.dart';

import '../domain/attention_signals.dart';
import 'ios_temporal_coherence.dart';

/// 웹(Safari·Chrome) JPEG → [AttentionSignals].
///
/// iOS 네이티브와 달리 Vercel 웹은 이 경로만 탑니다.
/// 카메라 실패·빈 화면·포스터 오검 시 `facePresent: true`가 되지 않도록
/// 점수·면적·EAR 생물학적 변화(라치)를 적용합니다.
class WebAttentionFacePipeline {
  WebAttentionFacePipeline();

  static const _minDetectionScore = 0.92;
  static const _minFastGateScore = 0.92;
  static const _minFaceAreaRatio = 0.06;
  static const int _latchFrames = 4;

  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  static const double _earVarianceMin = 0.014;

  final IosTemporalCoherence _coherence = IosTemporalCoherence();
  final List<double> _earLHistory = [];
  final List<double> _earRHistory = [];
  int _rawFaceStreak = 0;
  int _rawNoFaceStreak = 0;
  bool _latched = false;

  void reset() {
    _coherence.reset();
    _earLHistory.clear();
    _earRHistory.clear();
    _rawFaceStreak = 0;
    _rawNoFaceStreak = 0;
    _latched = false;
  }

  /// 카메라 실패·분석 불가 시 — 절대 `facePresent: true` 를 내지 않습니다.
  AttentionSignals noFace(bool inForeground) => AttentionSignals(
        facePresent: false,
        multiFace: false,
        appInForeground: inForeground,
      );

  /// JPEG이 너무 작거나 단색이면 검출하지 않습니다.
  static bool jpegLooksLikePhoto(Uint8List bytes) {
    if (bytes.length < 8000) return false;
    final step = math.max(1, bytes.length ~/ 400);
    var minV = 255;
    var maxV = 0;
    for (var i = 0; i < bytes.length; i += step) {
      final v = bytes[i];
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    return (maxV - minV) >= 20;
  }

  static bool passesFastGate(Face face) {
    if (face.detectionData.score < _minFastGateScore) return false;
    final bb = face.boundingBox;
    final bw = bb.width.abs();
    final bh = bb.height.abs();
    if (bw < 36 || bh < 36) return false;
    final frameArea = face.originalSize.width * face.originalSize.height;
    if (frameArea < 1) return false;
    return (bw * bh) / frameArea >= _minFaceAreaRatio;
  }

  static List<Face> filterTrustworthy(
    List<Face> faces, {
    List<Face>? requireFastOverlap,
  }) {
    final trusted = faces.where(_isTrustworthyFace).toList();
    if (requireFastOverlap == null || requireFastOverlap.isEmpty) {
      return trusted;
    }
    return trusted
        .where((f) => _overlapsAny(f, requireFastOverlap))
        .toList();
  }

  static bool _overlapsAny(Face full, List<Face> fastGates) {
    for (final fast in fastGates) {
      if (_boxOverlapRatio(full.boundingBox, fast.boundingBox) >= 0.35) {
        return true;
      }
    }
    return false;
  }

  static double _boxOverlapRatio(BoundingBox a, BoundingBox b) {
    final ix1 = math.max(a.left, b.left);
    final iy1 = math.max(a.top, b.top);
    final ix2 = math.min(a.right, b.right);
    final iy2 = math.min(a.bottom, b.bottom);
    if (ix2 <= ix1 || iy2 <= iy1) return 0;
    final inter = (ix2 - ix1) * (iy2 - iy1);
    final union = a.width * a.height + b.width * b.height - inter;
    return union <= 0 ? 0 : inter / union;
  }

  static bool _isTrustworthyFace(Face face) {
    final mesh = face.mesh;
    if (mesh == null || mesh.length < 468) return false;
    if (face.detectionData.score < _minDetectionScore) return false;
    final bb = face.boundingBox;
    if (bb.width.abs() < 36 || bb.height.abs() < 36) return false;
    final frameArea = face.originalSize.width * face.originalSize.height;
    if (frameArea < 1) return false;
    if ((bb.width * bb.height) / frameArea < _minFaceAreaRatio) return false;
    final earL = _ear(mesh, _eyeL);
    final earR = _ear(mesh, _eyeR);
    return _earPlausible(earL) && _earPlausible(earR);
  }

  static bool _earPlausible(double ear) => ear >= 0.16 && ear <= 0.42;

  /// 검출 결과를 안정화한 뒤 [AttentionSignals] 반환.
  AttentionSignals processFaces(List<Face> faces, bool inForeground) {
    final raw = _rawFromFaces(faces, inForeground);
    return _stabilize(raw, faces);
  }

  AttentionSignals _rawFromFaces(List<Face> faces, bool inForeground) {
    if (faces.isEmpty) {
      return noFace(inForeground);
    }
    final face = faces.first;
    final mesh = face.mesh;
    if (mesh == null || mesh.length < 468) {
      return noFace(inForeground);
    }
    final earL = _ear(mesh, _eyeL);
    final earR = _ear(mesh, _eyeR);
    if (!_earPlausible(earL) || !_earPlausible(earR)) {
      return noFace(inForeground);
    }
    final blink = earL < 0.2 && earR < 0.2;
    final pose = _estimateHeadPose(mesh);
    return AttentionSignals(
      facePresent: true,
      multiFace: faces.length > 1,
      appInForeground: inForeground,
      earLeft: earL,
      earRight: earR,
      headYaw: pose.$1,
      headPitch: pose.$2,
      blinkFrame: blink,
    );
  }

  AttentionSignals _stabilize(AttentionSignals raw, List<Face> faces) {
    if (raw.facePresent && faces.isNotEmpty) {
      final face = faces.first;
      final bb = face.boundingBox;
      final fw = face.originalSize.width.toDouble();
      final fh = face.originalSize.height.toDouble();

      if (!_coherence.consumeAndIsPlausible(
        bboxLeft: bb.left,
        bboxTop: bb.top,
        bboxRight: bb.right,
        bboxBottom: bb.bottom,
        earL: raw.earLeft,
        earR: raw.earRight,
        frameWidth: fw,
        frameHeight: fh,
      )) {
        raw = noFace(raw.appInForeground);
      }
    } else {
      _coherence.reset();
    }

    if (raw.facePresent) {
      _rawFaceStreak++;
      _rawNoFaceStreak = 0;
      _earLHistory.add(raw.earLeft);
      _earRHistory.add(raw.earRight);
      if (_earLHistory.length > _latchFrames) {
        _earLHistory.removeAt(0);
        _earRHistory.removeAt(0);
      }
      if (_rawFaceStreak >= _latchFrames && _earHasSufficientVariance()) {
        _latched = true;
      }
    } else {
      _rawNoFaceStreak++;
      _rawFaceStreak = 0;
      _earLHistory.clear();
      _earRHistory.clear();
      if (_rawNoFaceStreak >= 1) _latched = false;
    }

    if (!_latched) {
      return noFace(raw.appInForeground);
    }
    return raw;
  }

  bool _earHasSufficientVariance() {
    if (_earLHistory.length < _latchFrames) return false;
    var minL = _earLHistory[0];
    var maxL = _earLHistory[0];
    var minR = _earRHistory[0];
    var maxR = _earRHistory[0];
    for (final v in _earLHistory) {
      if (v < minL) minL = v;
      if (v > maxL) maxL = v;
    }
    for (final v in _earRHistory) {
      if (v < minR) minR = v;
      if (v > maxR) maxR = v;
    }
    return (maxL - minL) >= _earVarianceMin ||
        (maxR - minR) >= _earVarianceMin;
  }

  static double _ear(FaceMesh mesh, List<int> idx) {
    final p0 = mesh[idx[0]];
    final p1 = mesh[idx[1]];
    final p2 = mesh[idx[2]];
    final p3 = mesh[idx[3]];
    final p4 = mesh[idx[4]];
    final p5 = mesh[idx[5]];
    final v1 = _dist(p1, p5);
    final v2 = _dist(p2, p4);
    final h = _dist(p0, p3);
    if (h < 1e-6) return 0.0;
    return (v1 + v2) / (2.0 * h);
  }

  static double _dist(Point a, Point b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static (double, double) _estimateHeadPose(FaceMesh mesh) {
    try {
      final nose = mesh[1];
      final eyeL = mesh[226];
      final eyeR = mesh[446];
      final chin = mesh[152];
      final eyeCx = (eyeL.x + eyeR.x) / 2;
      final eyeCy = (eyeL.y + eyeR.y) / 2;
      final eyeWidth = (eyeR.x - eyeL.x).abs();
      if (eyeWidth < 1e-6) return (0.0, 0.0);
      final yaw = ((nose.x - eyeCx) / eyeWidth) * 90.0;
      final faceHeight = (chin.y - eyeCy).abs().clamp(1.0, double.infinity);
      final pitch = (((nose.y - eyeCy) / faceHeight) - 0.35) * 120.0;
      return (yaw, pitch);
    } catch (_) {
      return (0.0, 0.0);
    }
  }
}

/// 하위 호환: 단순 변환 (테스트·레거시). 실제 웹 UI는 [WebAttentionFacePipeline] 사용.
AttentionSignals attentionSignalsFromFaces(List<Face> faces, bool inForeground) {
  return WebAttentionFacePipeline().processFaces(faces, inForeground);
}
