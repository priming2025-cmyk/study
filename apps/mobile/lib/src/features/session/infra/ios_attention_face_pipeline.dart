import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

/// iOS 공통: 기종·OS 버전마다 다른 카메라 버퍼·회전에 맞춘 얼굴 검증.
///
/// - 여러 [DeviceOrientation]·[CameraFrameRotation] 후보 중 **가장 신뢰도 높은** 결과 선택
/// - 임계값은 Android에 가깝게 유지 (특정 iPhone만 통과하는 조건 지양)
class IosAttentionFacePipeline {
  IosAttentionFacePipeline._();

  static const _minDetectionScore = 0.72;
  static const _minFastGateScore = 0.68;
  static const _minFaceAreaRatio = 0.04;
  static const _minBoxSide = 28.0;

  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  /// 완전 검은 프레임만 건너뜁니다 (어두운 방·구형 iPhone 포함).
  static bool frameLooksLikeLiveCamera(CameraImage image) {
    if (image.planes.isEmpty) return false;
    final Uint8List bytes = image.planes.first.bytes;
    if (bytes.length < 128) return false;

    final step = math.max(1, bytes.length ~/ 300);
    var sum = 0.0;
    var sumSq = 0.0;
    var n = 0;
    for (var i = 0; i < bytes.length; i += step) {
      final v = bytes[i].toDouble();
      sum += v;
      sumSq += v * v;
      n++;
    }
    if (n < 6) return false;
    final mean = sum / n;
    if (mean < 4) return false;
    final variance = sumSq / n - mean * mean;
    return variance > 18;
  }

  /// iOS 기종별 sensorOrientation·버퍼 레이아웃 차이 → 회전 후보를 넓게 시도.
  static List<CameraFrameRotation?> rotationCandidates({
    required CameraDescription cam,
    required CameraImage image,
    DeviceOrientation? reportedOrientation,
  }) {
    final seen = <CameraFrameRotation?>{};
    final out = <CameraFrameRotation?>[];

    void add(CameraFrameRotation? r) {
      if (seen.add(r)) out.add(r);
    }

    for (final orient in <DeviceOrientation?>[
      reportedOrientation,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]) {
      if (orient == null) continue;
      add(
        rotationForFrame(
          width: image.width,
          height: image.height,
          sensorOrientation: cam.sensorOrientation,
          isFrontCamera: cam.lensDirection == CameraLensDirection.front,
          deviceOrientation: orient,
        ),
      );
    }

    for (final r in <CameraFrameRotation?>[
      null,
      CameraFrameRotation.cw90,
      CameraFrameRotation.cw180,
      CameraFrameRotation.cw270,
    ]) {
      add(r);
    }
    return out;
  }

  static bool passesFastGate(Face face) {
    if (face.detectionData.score < _minFastGateScore) return false;
    final bb = face.boundingBox;
    final bw = bb.width.abs();
    final bh = bb.height.abs();
    if (bw < _minBoxSide || bh < _minBoxSide) return false;
    final frameArea = face.originalSize.width * face.originalSize.height;
    if (frameArea < 1) return false;
    return (bw * bh) / frameArea >= _minFaceAreaRatio;
  }

  static bool jpegLooksLikePhoto(Uint8List bytes) {
    if (bytes.length < 8000) return false;
    final step = math.max(1, bytes.length ~/ 500);
    var minV = 255;
    var maxV = 0;
    for (var i = 0; i < bytes.length; i += step) {
      final v = bytes[i];
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    return (maxV - minV) >= 16;
  }

  static bool earsPlausible(double earL, double earR) =>
      _earPlausible(earL) && _earPlausible(earR);

  static List<Face> filterTrustworthy(
    List<Face> faces, {
    List<Face>? requireFastOverlap,
  }) {
    final trusted = <Face>[];
    for (final f in faces) {
      if (isTrustworthyFace(f)) {
        trusted.add(f);
        continue;
      }
      if (_softAcceptFace(f)) trusted.add(f);
    }
    if (requireFastOverlap == null || requireFastOverlap.isEmpty) {
      return trusted;
    }
    return trusted
        .where((f) => _overlapsAnyFastGate(f, requireFastOverlap))
        .toList();
  }

  /// 검출 점수·mesh·박스 크기로 회전 후보 중 최적 얼굴 순위.
  static double rankFace(Face face) {
    var score = face.detectionData.score;
    final mesh = face.mesh;
    if (mesh != null && mesh.length >= 468) score += 0.12;
    final bb = face.boundingBox;
    final areaRatio = (bb.width.abs() * bb.height.abs()) /
        math.max(1.0, face.originalSize.width * face.originalSize.height);
    score += areaRatio.clamp(0.0, 0.15);
    return score;
  }

  static bool _softAcceptFace(Face face) {
    final mesh = face.mesh;
    if (mesh == null || mesh.length < 468) return false;
    if (face.detectionData.score < _minDetectionScore) return false;
    final bb = face.boundingBox;
    if (bb.width.abs() < _minBoxSide || bb.height.abs() < _minBoxSide) {
      return false;
    }
    final earL = _ear(mesh, _eyeL);
    final earR = _ear(mesh, _eyeR);
    return _earPlausible(earL) && _earPlausible(earR);
  }

  static bool _overlapsAnyFastGate(Face full, List<Face> fastGates) {
    for (final fast in fastGates) {
      if (_boxOverlapRatio(full.boundingBox, fast.boundingBox) >= 0.28) {
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

    final interArea = (ix2 - ix1) * (iy2 - iy1);
    final union = a.width * a.height + b.width * b.height - interArea;
    if (union <= 0) return 0;
    return interArea / union;
  }

  static bool isTrustworthyFace(Face face) {
    final mesh = face.mesh;
    if (mesh == null || mesh.length < 468) return false;
    if (face.detectionData.score < _minDetectionScore) return false;

    final bb = face.boundingBox;
    final bw = bb.width.abs();
    final bh = bb.height.abs();
    if (bw < _minBoxSide || bh < _minBoxSide) return false;

    final frameArea = face.originalSize.width * face.originalSize.height;
    if (frameArea < 1) return false;
    if ((bw * bh) / frameArea < _minFaceAreaRatio) return false;

    if (!_meshGeometryOk(mesh)) return false;

    final earL = _ear(mesh, _eyeL);
    final earR = _ear(mesh, _eyeR);
    return _earPlausible(earL) && _earPlausible(earR);
  }

  static bool _earPlausible(double ear) => ear >= 0.12 && ear <= 0.50;

  static bool _meshGeometryOk(FaceMesh mesh) {
    try {
      final rOut = mesh[33];
      final lOut = mesh[263];
      final nose = mesh[1];
      final chin = mesh[152];

      final interEye = math.sqrt(
        math.pow(rOut.x - lOut.x, 2) + math.pow(rOut.y - lOut.y, 2),
      );
      if (interEye < 22 || interEye > 280) return false;

      final eyeMidX = (rOut.x + lOut.x) / 2;
      if ((nose.x - eyeMidX).abs() > interEye * 0.55) return false;

      final eyeMidY = (rOut.y + lOut.y) / 2;
      final faceH = (chin.y - eyeMidY).abs();
      if (faceH < 28 || faceH > 520) return false;

      final ratio = interEye / faceH;
      if (ratio < 0.14 || ratio > 0.62) return false;

      return true;
    } catch (_) {
      return false;
    }
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
}
