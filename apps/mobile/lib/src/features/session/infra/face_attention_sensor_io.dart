import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';

import '../domain/attention_signals.dart';
import 'ios_attention_face_pipeline.dart';

/// 앱(iOS·Android·macOS)용 얼굴 집중도 센서.
///
/// - **Android**: YUV420 + [rotationForFrame] + `detectFacesFromCameraImage`.
/// - **iOS**: BGRA + [rotationForFrame] + [IosAttentionFacePipeline] (공식 예제와 동일 축).
/// - **macOS**: BGRA + `prepareCameraFrame`.
class FaceAttentionSensor {
  FaceDetector? _detector;
  IosAttentionFacePipeline? _iosPipeline;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  bool _running = false;
  bool _busy = false;

  int _iosRawFaceStreak = 0;
  int _iosRawNoFaceStreak = 0;
  bool _iosLatchedFacePresent = false;

  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  /// iOS: 연속 N프레임에서만 ‘얼굴 있음’ 고정(오검 1~2프레임 차단).
  static const int _iosFaceLatchFrames = 3;

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
    if (Platform.isIOS) {
      _iosPipeline = IosAttentionFacePipeline(_detector!);
    }

    final isMacOS = Platform.isMacOS;
    final isIOS = Platform.isIOS;
    _controller = CameraController(
      cam,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: (isMacOS || isIOS)
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
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
        } else if (isIOS) {
          final pipeline = _iosPipeline;
          if (pipeline == null) {
            faces = const [];
          } else {
            faces = await pipeline.detect(
              image: image,
              camera: cam,
              deviceOrientation: controller.value.deviceOrientation,
            );
          }
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
        if (isIOS) {
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

  AttentionSignals _iosStabilizeFacePresent(AttentionSignals raw) {
    if (raw.facePresent) {
      _iosRawFaceStreak++;
      _iosRawNoFaceStreak = 0;
      if (_iosRawFaceStreak >= _iosFaceLatchFrames) {
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
    _iosPipeline = null;
    await _detector?.dispose();
    _detector = null;
    await _signals?.close();
    _signals = null;
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
    if (Platform.isIOS) {
      if (earL < 0.12 || earR < 0.12 || earL > 0.48 || earR > 0.48) {
        return AttentionSignals(
          facePresent: false,
          multiFace: false,
          appInForeground: inForeground,
        );
      }
    }

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
