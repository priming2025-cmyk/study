import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';

/// iOS 전용: 단일 프레임 얼굴 검출 결과가 **진짜 얼굴**인지 검증.
///
/// 시간 축 생물학적 검증(EAR 변화)은 [FaceAttentionSensor._iosStabilizeFacePresent]에서 담당합니다.
class IosAttentionFacePipeline {
  IosAttentionFacePipeline._();

  static const _minDetectionScore = 0.95;
  static const _minFastGateScore = 0.95;
  static const _minFaceAreaRatio = 0.08;

  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  /// 검은 화면·초기 빈 프레임(분산 거의 없음)은 검출하지 않습니다.
  static bool frameLooksLikeLiveCamera(CameraImage image) {
    if (image.planes.isEmpty) return false;
    final Uint8List bytes = image.planes.first.bytes;
    if (bytes.length < 256) return false;

    final step = math.max(1, bytes.length ~/ 400);
    var sum = 0.0;
    var sumSq = 0.0;
    var n = 0;
    for (var i = 0; i < bytes.length; i += step) {
      final v = bytes[i].toDouble();
      sum += v;
      sumSq += v * v;
      n++;
    }
    if (n < 8) return false;
    final mean = sum / n;
    final variance = sumSq / n - mean * mean;
    return variance > 90;
  }

  /// fast 검출(박스만)로 1차 게이트 — mesh 오검 전에 걸러냅니다.
  static bool passesFastGate(Face face) {
    if (face.detectionData.score < _minFastGateScore) return false;
    final bb = face.boundingBox;
    final bw = bb.width.abs();
    final bh = bb.height.abs();
    if (bw < 40 || bh < 40) return false;
    final frameArea = face.originalSize.width * face.originalSize.height;
    if (frameArea < 1) return false;
    return (bw * bh) / frameArea >= _minFaceAreaRatio;
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

  static bool earsPlausible(double earL, double earR) =>
      _earPlausible(earL) && _earPlausible(earR);

  static List<Face> filterTrustworthy(
    List<Face> faces, {
    List<Face>? requireFastOverlap,
  }) {
    final trusted = faces.where(isTrustworthyFace).toList();
    if (requireFastOverlap == null || requireFastOverlap.isEmpty) {
      return trusted;
    }
    return trusted
        .where((f) => _overlapsAnyFastGate(f, requireFastOverlap))
        .toList();
  }

  static bool _overlapsAnyFastGate(Face full, List<Face> fastGates) {
    for (final fast in fastGates) {
      if (_boxOverlapRatio(full.boundingBox, fast.boundingBox) >= 0.35) {
        return true;
      }
    }
    return false;
  }

  static double _boxOverlapRatio(BoundingBox a, BoundingBox b) {
    final ax1 = a.left;
    final ay1 = a.top;
    final ax2 = a.right;
    final ay2 = a.bottom;
    final bx1 = b.left;
    final by1 = b.top;
    final bx2 = b.right;
    final by2 = b.bottom;

    final ix1 = math.max(ax1, bx1);
    final iy1 = math.max(ay1, by1);
    final ix2 = math.min(ax2, bx2);
    final iy2 = math.min(ay2, by2);
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
    if (bw < 40 || bh < 40) return false;

    final frameArea = face.originalSize.width * face.originalSize.height;
    if (frameArea < 1) return false;
    if ((bw * bh) / frameArea < _minFaceAreaRatio) return false;

    if (!_meshGeometryOk(mesh)) return false;

    final earL = _ear(mesh, _eyeL);
    final earR = _ear(mesh, _eyeR);
    if (!_earPlausible(earL) || !_earPlausible(earR)) return false;

    return true;
  }

  static bool _earPlausible(double ear) => ear >= 0.17 && ear <= 0.40;

  static bool _meshGeometryOk(FaceMesh mesh) {
    try {
      final rOut = mesh[33];
      final lOut = mesh[263];
      final nose = mesh[1];
      final chin = mesh[152];

      final interEye = math.sqrt(
        math.pow(rOut.x - lOut.x, 2) + math.pow(rOut.y - lOut.y, 2),
      );
      if (interEye < 48 || interEye > 200) return false;

      final eyeMidX = (rOut.x + lOut.x) / 2;
      if ((nose.x - eyeMidX).abs() > interEye * 0.45) return false;

      final eyeMidY = (rOut.y + lOut.y) / 2;
      final faceH = (chin.y - eyeMidY).abs();
      if (faceH < 56 || faceH > 420) return false;

      final ratio = interEye / faceH;
      if (ratio < 0.2 || ratio > 0.52) return false;

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

