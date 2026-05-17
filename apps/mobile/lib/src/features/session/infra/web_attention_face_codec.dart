import 'dart:math' as math;
import 'dart:typed_data';

import 'package:face_detection_tflite/face_detection_tflite.dart';

import '../domain/attention_signals.dart';
import 'ios_temporal_coherence.dart';

/// 웹(Safari·Chrome) 얼굴 검출 → [AttentionSignals].
///
/// 모바일 Safari는 프레임 간격이 길어 EAR 분산이 작을 수 있어,
/// **연속 N프레임 + bbox 안정성**만으로 라치합니다 (EAR 분산 조건 제거).
class WebAttentionFacePipeline {
  WebAttentionFacePipeline();

  static const _minDetectionScore = 0.75;
  static const _minFastGateScore = 0.65;
  static const _minFaceAreaRatio = 0.04;
  static const int _latchFrames = 1;

  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  final IosTemporalCoherence _coherence = IosTemporalCoherence();
  int _rawFaceStreak = 0;
  int _rawNoFaceStreak = 0;
  bool _latched = false;

  void reset() {
    _coherence.reset();
    _rawFaceStreak = 0;
    _rawNoFaceStreak = 0;
    _latched = false;
  }

  /// JPEG가 너무 작거나 단색에 가까우면 검출하지 않습니다.
  static bool jpegLooksLikePhoto(Uint8List bytes) {
    if (bytes.length < 12000) return false;
    final step = math.max(1, bytes.length ~/ 500);
    var minV = 255;
    var maxV = 0;
    for (var i = 0; i < bytes.length; i += step) {
      final v = bytes[i];
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    return (maxV - minV) >= 24;
  }

  AttentionSignals noFace(bool inForeground) => AttentionSignals(
        facePresent: false,
        multiFace: false,
        appInForeground: inForeground,
      );

  static bool passesFastGate(Face face) {
    if (face.detectionData.score < _minFastGateScore) return false;
    final bb = face.boundingBox;
    if (bb.width.abs() < 32 || bb.height.abs() < 32) return false;
    final frameArea = face.originalSize.width * face.originalSize.height;
    if (frameArea < 1) return false;
    return (bb.width * bb.height) / frameArea >= _minFaceAreaRatio;
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
      if (_boxOverlapRatio(full.boundingBox, fast.boundingBox) >= 0.30) {
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
    if (bb.width.abs() < 32 || bb.height.abs() < 32) return false;
    final frameArea = face.originalSize.width * face.originalSize.height;
    if (frameArea < 1) return false;
    if ((bb.width * bb.height) / frameArea < _minFaceAreaRatio) return false;
    final earL = _ear(mesh, _eyeL);
    final earR = _ear(mesh, _eyeR);
    return earL >= 0.14 && earL <= 0.45 && earR >= 0.14 && earR <= 0.45;
  }

  /// full mesh 우선, 없으면 fast 박스만으로 판정.
  AttentionSignals processDetection({
    required List<Face> fullFaces,
    required List<Face> fastFaces,
    required bool inForeground,
  }) {
    var trusted = filterTrustworthy(
      fullFaces,
      requireFastOverlap: fastFaces.where(passesFastGate).toList(),
    );
    if (trusted.isNotEmpty) {
      return _stabilize(_rawFromFaces(trusted, inForeground), trusted);
    }

    final fastOk = fastFaces.where(passesFastGate).toList();
    if (fastOk.isEmpty) {
      return _stabilize(noFace(inForeground), const []);
    }
    return _stabilizeFastOnly(fastOk, inForeground);
  }

  AttentionSignals processFaces(List<Face> faces, bool inForeground) {
    return processDetection(
      fullFaces: faces,
      fastFaces: faces,
      inForeground: inForeground,
    );
  }

  AttentionSignals _rawFromFaces(List<Face> faces, bool inForeground) {
    if (faces.isEmpty) return noFace(inForeground);
    final face = faces.first;
    final mesh = face.mesh;
    if (mesh == null || mesh.length < 468) return noFace(inForeground);

    final earL = _ear(mesh, _eyeL);
    final earR = _ear(mesh, _eyeR);
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

  /// fast 박스만 있을 때: bbox 안정성 + 2프레임 라치.
  AttentionSignals _stabilizeFastOnly(List<Face> fastOk, bool inForeground) {
    final face = fastOk.first;
    final bb = face.boundingBox;
    final fw = face.originalSize.width.toDouble();
    final fh = face.originalSize.height.toDouble();

    if (!_coherence.consumeAndIsPlausible(
      bboxLeft: bb.left,
      bboxTop: bb.top,
      bboxRight: bb.right,
      bboxBottom: bb.bottom,
      earL: 0.28,
      earR: 0.28,
      frameWidth: fw,
      frameHeight: fh,
    )) {
      return _stabilize(noFace(inForeground), const []);
    }

    final raw = AttentionSignals(
      facePresent: true,
      multiFace: fastOk.length > 1,
      appInForeground: inForeground,
      earLeft: 0.28,
      earRight: 0.28,
    );
    return _stabilize(raw, fastOk);
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
      if (_rawFaceStreak >= _latchFrames) {
        _latched = true;
      }
    } else {
      _rawNoFaceStreak++;
      _rawFaceStreak = 0;
      if (_rawNoFaceStreak >= 1) _latched = false;
    }

    if (!_latched) {
      return noFace(raw.appInForeground);
    }
    return raw;
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

AttentionSignals attentionSignalsFromFaces(List<Face> faces, bool inForeground) {
  return WebAttentionFacePipeline().processFaces(faces, inForeground);
}
