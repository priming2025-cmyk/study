import 'dart:math' as math;

import 'package:face_detection_tflite/face_detection_tflite.dart';

import '../domain/attention_signals.dart';

/// [Face] 목록을 [AttentionSignals]로 변환 (웹·동일 로직 공용).
AttentionSignals attentionSignalsFromFaces(List<Face> faces, bool inForeground) {
  if (faces.isEmpty) {
    return AttentionSignals(
      facePresent: false,
      multiFace: false,
      appInForeground: inForeground,
    );
  }

  final face = faces.first;
  final mesh = face.mesh;

  double earL = 0.3, earR = 0.3;
  double yaw = 0, pitch = 0;
  var blink = false;

  if (mesh != null && mesh.length >= 468) {
    earL = _ear(mesh, _eyeL);
    earR = _ear(mesh, _eyeR);
    blink = earL < 0.2 && earR < 0.2;

    final pose = _estimateHeadPose(mesh);
    yaw = pose.$1;
    pitch = pose.$2;
  }

  return AttentionSignals(
    facePresent: true,
    multiFace: faces.length > 1,
    appInForeground: inForeground,
    earLeft: earL,
    earRight: earR,
    headYaw: yaw,
    headPitch: pitch,
    blinkFrame: blink,
  );
}

// MediaPipe 468-point mesh 눈 윤곽 6점
const _eyeL = [362, 385, 387, 263, 373, 380];
const _eyeR = [33, 160, 158, 133, 153, 144];

double _ear(FaceMesh mesh, List<int> idx) {
  final p0 = mesh[idx[0]];
  final p1 = mesh[idx[1]];
  final p2 = mesh[idx[2]];
  final p3 = mesh[idx[3]];
  final p4 = mesh[idx[4]];
  final p5 = mesh[idx[5]];
  final v1 = _dist(p1, p5);
  final v2 = _dist(p2, p4);
  final h = _dist(p0, p3);
  if (h < 1e-6) return 0.3;
  return (v1 + v2) / (2.0 * h);
}

double _dist(Point a, Point b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

(double, double) _estimateHeadPose(FaceMesh mesh) {
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
