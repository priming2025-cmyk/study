import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import '../domain/attention_signals.dart';

/// `rotationForFrame`의 **Android 분기**와 동일한 수식 (센서·전후면·기기 회전).
///
/// iOS 전용 `rotationForFrame`은 “AVFoundation이 이미 세로로 맞춘다”는 가정으로
/// 세로 들고 **가로로 긴 버퍼**에서만 90/270을 넣는데, 실제 `camera` 스트림은
/// 기기마다 다르게 나와 **회전이 빗나간 채 null**인 경우가 있어 빈 화면도
/// 얼굴+mesh로 안정 오검될 수 있음 → iOS에서도 Android와 같은 회전을 씀.
CameraFrameRotation? rotationForCameraFrameLikeAndroid({
  required int sensorOrientation,
  required bool isFrontCamera,
  required DeviceOrientation deviceOrientation,
}) {
  final int deviceRotation = switch (deviceOrientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };

  final int total = isFrontCamera
      ? (sensorOrientation + deviceRotation) % 360
      : (sensorOrientation - deviceRotation + 360) % 360;

  return switch (total) {
    90 => CameraFrameRotation.cw90,
    180 => CameraFrameRotation.cw180,
    270 => CameraFrameRotation.cw270,
    _ => null,
  };
}

/// 앱(iOS·Android·macOS·Windows·Linux)용 얼굴 집중도 센서.
///
/// - **웹**: JPEG + `detectFaces` (세션 화면의 `SessionSelfCameraSurface` 경로).
/// - **Android**: `yuv420` + `detectFacesFromCameraImage` + `rotationForFrame` + `isBgra:false`
///   — `rotationForFrame`의 **Android 전용** 수식(센서±기기)이 적용됨.
/// - **iOS**: `rotationForFrame`의 iOS 분기 대신 [rotationForCameraFrameLikeAndroid]로
///   Android와 **동일한 회전 규칙**을 적용하고, mesh 기하·짧은 안정화로 오검을 완화.
/// - **macOS**: `bgra8888` + `prepareCameraFrame` (YUV 미지원).
class FaceAttentionSensor {
  FaceDetector? _detector;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  bool _running = false;
  bool _busy = false;

  /// iOS: ‘얼굴 있음’을 스트림에보내기 전 짧은 안정화(오검 1~2프레임 차단).
  int _iosRawFaceStreak = 0;
  int _iosRawNoFaceStreak = 0;
  bool _iosLatchedFacePresent = false;

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

    if (Platform.isIOS) {
      _iosRawFaceStreak = 0;
      _iosRawNoFaceStreak = 0;
      _iosLatchedFacePresent = false;
    }

    _detector = FaceDetector();
    await _detector!.initialize(
      model: cam.lensDirection == CameraLensDirection.front
          ? FaceDetectionModel.frontCamera
          : FaceDetectionModel.backCamera,
    );

    final isMacOS = Platform.isMacOS;
    _controller = CameraController(
      cam,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup:
          isMacOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();

    await _controller!.startImageStream((image) async {
      if (!_running || _busy) return;
      _busy = true;
      try {
        final controller = _controller;
        if (controller == null || !controller.value.isInitialized) {
          return;
        }

        List<Face> faces;

        if (isMacOS) {
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
            rotation: null,
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
        } else if (Platform.isIOS) {
          // iOS는 패키지의 rotationForFrame(iOS 분기)이 스트림 실제 방향과 어긋나
          // 빈 화면이 얼굴로 고정되는 사례가 있어, Android와 동일한 회전식을 사용.
          final rotation = rotationForCameraFrameLikeAndroid(
            sensorOrientation: cam.sensorOrientation,
            isFrontCamera: cam.lensDirection == CameraLensDirection.front,
            deviceOrientation: controller.value.deviceOrientation,
          );
          faces = await _detector!
              .detectFacesFromCameraImage(
                image,
                rotation: rotation,
                isBgra: false,
                mode: FaceDetectionMode.full,
                maxDim: 320,
              )
              .timeout(const Duration(milliseconds: 1500));
          faces = faces.where(_iosPlausibleFace).toList();
        } else {
          final rotation = rotationForFrame(
            width: image.width,
            height: image.height,
            sensorOrientation: cam.sensorOrientation,
            isFrontCamera: cam.lensDirection == CameraLensDirection.front,
            deviceOrientation: controller.value.deviceOrientation,
          );
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

        var sig = _toSignals(faces, appInForeground());
        if (Platform.isIOS) {
          sig = _iosStabilizeFacePresent(sig);
        }
        _signals?.add(sig);
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

  /// iOS: raw 검출이 있어도 **연속 2프레임**에서만 `facePresent` true.
  /// 얼굴 이탈은 **1프레임** 없으면 바로 false (사용자가 기대하는 ‘자리비움’ 반응).
  AttentionSignals _iosStabilizeFacePresent(AttentionSignals raw) {
    if (raw.facePresent) {
      _iosRawFaceStreak++;
      _iosRawNoFaceStreak = 0;
      if (_iosRawFaceStreak >= 2) {
        _iosLatchedFacePresent = true;
      }
    } else {
      _iosRawNoFaceStreak++;
      _iosRawFaceStreak = 0;
      if (_iosRawNoFaceStreak >= 1) {
        _iosLatchedFacePresent = false;
      }
    }

    if (!_iosLatchedFacePresent) {
      return AttentionSignals(
        facePresent: false,
        multiFace: false,
        appInForeground: raw.appInForeground,
      );
    }

    return raw;
  }

  Stream<AttentionSignals> get stream =>
      _signals?.stream ?? const Stream.empty();

  CameraController? get controller => _controller;

  Future<void> stop() async {
    _running = false;
    if (Platform.isIOS) {
      _iosRawFaceStreak = 0;
      _iosRawNoFaceStreak = 0;
      _iosLatchedFacePresent = false;
    }
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

  /// iOS 전용: 점수·박스·mesh 기하로 오검 차단.
  static bool _iosPlausibleFace(Face face) {
    final mesh = face.mesh;
    if (mesh == null || mesh.length < 468) return false;
    if (face.detectionData.score < 0.62) return false;

    final bb = face.boundingBox;
    final bw = bb.width.abs();
    final bh = bb.height.abs();
    if (bw < 32 || bh < 32) return false;

    final frameArea = face.originalSize.width * face.originalSize.height;
    if (frameArea < 1) return false;
    final boxArea = bw * bh;
    if (boxArea / frameArea < 0.012) return false;

    if (!_iosMeshGeometryOk(mesh)) return false;

    return true;
  }

  /// 눈 간격·세로 비율 등으로 ‘얼굴 같은’ mesh인지 2차 검증.
  static bool _iosMeshGeometryOk(FaceMesh mesh) {
    try {
      // MediaPipe Face Mesh: 33(오른쪽 눈 바깥), 263(왼쪽 눈 바깥), 152(턱), 1(코)
      final rOut = mesh[33];
      final lOut = mesh[263];
      final nose = mesh[1];
      final chin = mesh[152];

      final interEye = math.sqrt(
        math.pow(rOut.x - lOut.x, 2) + math.pow(rOut.y - lOut.y, 2),
      );
      if (interEye < 38 || interEye > 240) return false;

      final eyeMidX = (rOut.x + lOut.x) / 2;
      if ((nose.x - eyeMidX).abs() > interEye * 0.52) return false;

      final eyeMidY = (rOut.y + lOut.y) / 2;
      final faceH = (chin.y - eyeMidY).abs();
      if (faceH < 48 || faceH > 520) return false;

      final ratio = interEye / faceH;
      if (ratio < 0.17 || ratio > 0.58) return false;

      return true;
    } catch (_) {
      return false;
    }
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
    if (mesh == null || mesh.length < 468) {
      return AttentionSignals(
        facePresent: false,
        multiFace: false,
        appInForeground: inForeground,
      );
    }

    final earL = _ear(mesh, _eyeL);
    final earR = _ear(mesh, _eyeR);
    final blink = earL < 0.2 && earR < 0.2;

    final pose = _estimateHeadPose(mesh);
    final yaw = pose.$1;
    final pitch = pose.$2;

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
}
