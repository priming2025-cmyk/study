import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

/// iOS 집중 세션용 얼굴 검출 (공식 예제와 동일한 회전·BGRA 경로 + 오검 차단).
///
/// 빈 화면에서도 ‘집중’이 뜨는 현상은 대개 **잘못된 픽셀 회전/YUV 해석**으로
/// mesh까지 나오는 오검에서 옵니다. Android식 회전을 iOS에 쓰지 않고
/// [rotationForFrame] + BGRA 프레임 변환을 사용합니다.
class IosAttentionFacePipeline {
  IosAttentionFacePipeline(this._detector);

  final FaceDetector _detector;

  static const _minDetectionScore = 0.72;
  static const _ambigAltScore = 0.65;

  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  /// 한 프레임에서 집중 신호에 쓸 얼굴 목록(0 또는 1명).
  Future<List<Face>> detect({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    final rotation = rotationForFrame(
      width: image.width,
      height: image.height,
      sensorOrientation: camera.sensorOrientation,
      isFrontCamera: camera.lensDirection == CameraLensDirection.front,
      deviceOrientation: deviceOrientation,
    );

    final primary = await _detectStrict(image, rotation);
    if (primary.isEmpty) return const [];

  // 빈 장면 오검: 서로 다른 회전에서도 얼굴이 잡히면 신뢰하지 않음.
    final altRotation = _alternateRotation(rotation);
    if (altRotation != rotation) {
      final alt = await _detectStrict(image, altRotation);
      if (alt.isNotEmpty &&
          alt.first.detectionData.score >= _ambigAltScore &&
          primary.first.detectionData.score >= _ambigAltScore) {
        return const [];
      }
    }

    return primary;
  }

  CameraFrameRotation? _alternateRotation(CameraFrameRotation? primary) {
    if (primary == null) return CameraFrameRotation.cw90;
    return null;
  }

  Future<List<Face>> _detectStrict(
    CameraImage image,
    CameraFrameRotation? rotation,
  ) async {
    final frame = prepareCameraFrame(
      width: image.width,
      height: image.height,
      planes: [
        for (final p in image.planes)
          (
            bytes: p.bytes,
            rowStride: p.bytesPerRow,
            pixelStride: p.bytesPerPixel ?? 4,
          ),
      ],
      rotation: rotation,
      isBgra: true,
    );
    if (frame == null) return const [];

    final faces = await _detector
        .detectFacesFromCameraFrame(
          frame,
          mode: FaceDetectionMode.full,
          maxDim: 320,
        )
        .timeout(const Duration(milliseconds: 1500));

    return faces.where(isTrustworthyFace).toList();
  }

  /// mesh·점수·박스·EAR로 ‘진짜 얼굴’만 통과.
  static bool isTrustworthyFace(Face face) {
    final mesh = face.mesh;
    if (mesh == null || mesh.length < 468) return false;
    if (face.detectionData.score < _minDetectionScore) return false;

    final bb = face.boundingBox;
    final bw = bb.width.abs();
    final bh = bb.height.abs();
    if (bw < 36 || bh < 36) return false;

    final frameArea = face.originalSize.width * face.originalSize.height;
    if (frameArea < 1) return false;
    if ((bw * bh) / frameArea < 0.015) return false;

    if (!_meshGeometryOk(mesh)) return false;

    final earL = _ear(mesh, _eyeL);
    final earR = _ear(mesh, _eyeR);
    if (!_earPlausible(earL) || !_earPlausible(earR)) return false;

    return true;
  }

  static bool _earPlausible(double ear) => ear >= 0.12 && ear <= 0.48;

  static bool _meshGeometryOk(FaceMesh mesh) {
    try {
      final rOut = mesh[33];
      final lOut = mesh[263];
      final nose = mesh[1];
      final chin = mesh[152];

      final interEye = math.sqrt(
        math.pow(rOut.x - lOut.x, 2) + math.pow(rOut.y - lOut.y, 2),
      );
      if (interEye < 42 || interEye > 220) return false;

      final eyeMidX = (rOut.x + lOut.x) / 2;
      if ((nose.x - eyeMidX).abs() > interEye * 0.48) return false;

      final eyeMidY = (rOut.y + lOut.y) / 2;
      final faceH = (chin.y - eyeMidY).abs();
      if (faceH < 52 || faceH > 480) return false;

      final ratio = interEye / faceH;
      if (ratio < 0.18 || ratio > 0.55) return false;

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
