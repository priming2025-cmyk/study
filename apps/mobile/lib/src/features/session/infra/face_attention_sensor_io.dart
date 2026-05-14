import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';

import '../domain/attention_signals.dart';

/// 앱(iOS·Android·macOS·Windows·Linux)용 얼굴 집중도 센서.
///
/// - **Android**: `yuv420` + `detectFacesFromCameraImage` (기존과 동일).
/// - **iOS**: `yuv420` 스트림은 NV12 평면/stride 조합에서 가끔 잘못 디코딩되어
///   mesh 단계가 실패한 채 bbox만 남는 `Face`가 나올 수 있습니다. 이 경우에도
///   예전 코드는 `facePresent: true`·기본 EAR로 **항상 집중**으로 보였습니다.
///   → iOS만 `bgra8888` + `prepareCameraFrame` + `detectFacesFromCameraFrame`으로
///   안정적인 BGR 입력을 쓰고, **468점 mesh가 있을 때만** 얼굴로 인정합니다.
/// - **macOS**: iOS와 동일한 BGRA 경로(기존 유지).
class FaceAttentionSensor {
  FaceDetector? _detector;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  bool _running = false;
  bool _busy = false;

  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  FaceAttentionSensor();

  Future<void> start({
    CameraDescription? camera,
    required bool Function() appInForeground,
    bool skipCameraEnumeration = false,
  }) async {
    if (_running) return;
    final cam = camera;
    if (cam == null) throw StateError('카메라가 필요합니다.');
    _running = true;

    _signals = StreamController<AttentionSignals>.broadcast();

    _detector = FaceDetector();
    await _detector!.initialize(
      model: cam.lensDirection == CameraLensDirection.front
          ? FaceDetectionModel.frontCamera
          : FaceDetectionModel.backCamera,
    );

    final useBgraStream = Platform.isIOS || Platform.isMacOS;
    _controller = CameraController(
      cam,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup:
          useBgraStream ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();

    await _controller!.startImageStream((image) async {
      if (!_running || _busy) return;
      _busy = true;
      try {
        final rotation = _rotationFor(cam, useBgraStream: useBgraStream);
        List<Face> faces;

        if (useBgraStream) {
          final frame = prepareCameraFrame(
            width: image.width,
            height: image.height,
            planes: [
              for (final p in image.planes)
                (
                  bytes: p.bytes,
                  rowStride: p.bytesPerRow,
                  pixelStride: p.bytesPerPixel ?? 4,
                )
            ],
            rotation: rotation,
            isBgra: true,
          );
          faces = frame == null
              ? const []
              : await _detector!
                  .detectFacesFromCameraFrame(
                    frame,
                    mode: FaceDetectionMode.full,
                    maxDim: 320,
                  )
                  .timeout(const Duration(milliseconds: 1500));
        } else {
          faces = await _detector!
              .detectFacesFromCameraImage(
                image,
                rotation: rotation,
                isBgra: false,
                mode: FaceDetectionMode.full,
                maxDim: 320,
              )
              .timeout(const Duration(milliseconds: 1500));
        }

        if (Platform.isIOS) {
          faces = faces.where(_iosPlausibleFace).toList();
        }

        _signals?.add(_toSignals(faces, appInForeground()));
      } catch (e) {
        debugPrint('FaceAttentionSensor: 감지 오류 → $e');
        _signals?.add(AttentionSignals(
          facePresent: false,
          multiFace: false,
          appInForeground: appInForeground(),
        ));
      } finally {
        _busy = false;
      }
    });
  }

  Stream<AttentionSignals> get stream =>
      _signals?.stream ?? const Stream.empty();

  CameraController? get controller => _controller;

  Future<void> stop() async {
    _running = false;
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    await _controller?.dispose();
    _controller = null;
    await _detector?.dispose();
    _detector = null;
    await _signals?.close();
    _signals = null;
  }

  /// iOS 전용: mesh가 없거나 너무 작은 박스·낮은 점수면 "얼굴 있음"으로 취급하지 않음.
  /// (face_detection_tflite 는 mesh 실패 시에도 `Face` 를 남길 수 있음)
  static bool _iosPlausibleFace(Face face) {
    final mesh = face.mesh;
    if (mesh == null || mesh.length < 468) return false;
    if (face.detectionData.score < 0.55) return false;

    final bb = face.boundingBox;
    final bw = bb.width.abs();
    final bh = bb.height.abs();
    if (bw < 28 || bh < 28) return false;

    final frameArea =
        face.originalSize.width * face.originalSize.height;
    if (frameArea < 1) return false;
    final boxArea = bw * bh;
    if (boxArea / frameArea < 0.008) return false;

    return true;
  }

  AttentionSignals _toSignals(List<Face> faces, bool inForeground) {
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

      final yawRatio = (nose.x - eyeCx) / eyeWidth;
      final yaw = yawRatio * 90.0;

      final faceHeight = (chin.y - eyeCy).abs().clamp(1.0, double.infinity);
      final pitchRatio = (nose.y - eyeCy) / faceHeight;
      final pitch = (pitchRatio - 0.35) * 120.0;

      return (yaw, pitch);
    } catch (_) {
      return (0.0, 0.0);
    }
  }

  /// BGRA(iOS·macOS): 플러그인이 이미 정방향 버퍼를 넘기는 경우가 많아 회전 null.
  /// Android(YUV): [sensorOrientation] 기준 회전 필요.
  CameraFrameRotation? _rotationFor(
    CameraDescription cam, {
    required bool useBgraStream,
  }) {
    if (kIsWeb) return null;
    if (useBgraStream) return null;
    return switch (cam.sensorOrientation) {
      90 => CameraFrameRotation.cw90,
      180 => CameraFrameRotation.cw180,
      270 => CameraFrameRotation.cw270,
      _ => null,
    };
  }
}
