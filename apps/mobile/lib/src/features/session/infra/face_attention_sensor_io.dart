import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import '../domain/attention_signals.dart';
import 'ios_attention_face_pipeline.dart';

/// iOS·Android·macOS 얼굴 집중 센서.
///
/// 모든 모바일 OS는 **YUV420 + 이미지 스트림 + [rotationForFrame]** 동일 경로.
/// iOS만 프레임 품질·mesh 검증·연속 프레임 래치로 오검을 억제합니다.
class FaceAttentionSensor {
  FaceDetector? _detector;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  bool _running = false;
  bool _busy = false;
  int _streamGeneration = 0;
  int _frameSkip = 0;

  int _iosRawFaceStreak = 0;
  int _iosRawNoFaceStreak = 0;
  bool _iosLatchedFacePresent = false;

  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  static const int _iosFaceLatchFrames = 6;
  static const int _iosFaceUnlatchFrames = 2;

  FaceAttentionSensor();

  Future<void> start({
    CameraDescription? camera,
    required bool Function() appInForeground,
    bool skipCameraEnumeration = false,
  }) async {
    final cam = camera;
    if (cam == null) throw StateError('카메라가 필요합니다.');

    await stop();
    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    _running = true;
    final gen = ++_streamGeneration;
    _frameSkip = 0;

    if (Platform.isIOS) {
      _iosRawFaceStreak = 0;
      _iosRawNoFaceStreak = 0;
      _iosLatchedFacePresent = false;
    }

    _signals = StreamController<AttentionSignals>.broadcast();

    _detector = FaceDetector();
    await _detector!.initialize(
      model: cam.lensDirection == CameraLensDirection.front
          ? FaceDetectionModel.frontCamera
          : FaceDetectionModel.backCamera,
    );

    final isMacOS = Platform.isMacOS;

    _controller = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          isMacOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();

    if (!_running || gen != _streamGeneration) {
      await _tearDownCameraOnly();
      return;
    }

    _emitNoFace(appInForeground());

    await _controller!.startImageStream((image) async {
      if (!_running || _busy || gen != _streamGeneration) return;

      if (Platform.isIOS) {
        _frameSkip++;
        if (_frameSkip % 3 != 0) return;
        if (!IosAttentionFacePipeline.frameLooksLikeLiveCamera(image)) {
          _emitIosStabilizedNoFace(appInForeground());
          return;
        }
      }

      _busy = true;
      try {
        final controller = _controller;
        if (controller == null || !controller.value.isInitialized) return;

        final faces = await _detectFrame(
          image: image,
          cam: cam,
          deviceOrientation: controller.value.deviceOrientation,
          isMacOS: isMacOS,
        );

        var sig = _toSignals(faces, appInForeground());
        if (Platform.isIOS) {
          sig = _iosStabilizeFacePresent(sig);
        }
        _signals?.add(sig);
      } catch (e) {
        debugPrint('FaceAttentionSensor: 감지 오류 → $e');
        if (Platform.isIOS) {
          _emitIosStabilizedNoFace(appInForeground());
        } else {
          _emitNoFace(appInForeground());
        }
      } finally {
        _busy = false;
      }
    });
  }

  Future<List<Face>> _detectFrame({
    required CameraImage image,
    required CameraDescription cam,
    required DeviceOrientation deviceOrientation,
    required bool isMacOS,
  }) async {
    if (isMacOS) {
      return _detectMacOS(image);
    }

    final rotation = rotationForFrame(
      width: image.width,
      height: image.height,
      sensorOrientation: cam.sensorOrientation,
      isFrontCamera: cam.lensDirection == CameraLensDirection.front,
      deviceOrientation: deviceOrientation,
    );

    if (Platform.isIOS) {
      return _detectIOSStream(image, rotation: rotation);
    }

    return _detector!
        .detectFacesFromCameraImage(
          image,
          rotation: rotation,
          isBgra: false,
          mode: FaceDetectionMode.full,
          maxDim: 320,
        )
        .timeout(const Duration(milliseconds: 1500));
  }

  Future<List<Face>> _detectIOSStream(
    CameraImage image, {
    required CameraFrameRotation? rotation,
  }) async {
    final fast = await _detector!
        .detectFacesFromCameraImage(
          image,
          rotation: rotation,
          isBgra: false,
          mode: FaceDetectionMode.fast,
          maxDim: 320,
        )
        .timeout(const Duration(milliseconds: 1200));

    final fastOk = fast.where(IosAttentionFacePipeline.passesFastGate).toList();
    if (fastOk.isEmpty) return const [];

    final full = await _detector!
        .detectFacesFromCameraImage(
          image,
          rotation: rotation,
          isBgra: false,
          mode: FaceDetectionMode.full,
          maxDim: 320,
        )
        .timeout(const Duration(milliseconds: 1500));

    return IosAttentionFacePipeline.filterTrustworthy(
      full,
      requireFastOverlap: fastOk,
    );
  }

  Future<List<Face>> _detectMacOS(CameraImage image) async {
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
      rotation: null,
      isBgra: true,
    );
    if (frame == null) return const [];
    return _detector!
        .detectFacesFromCameraFrame(
          frame,
          mode: FaceDetectionMode.full,
          maxDim: 320,
        )
        .timeout(const Duration(milliseconds: 1500));
  }

  void _emitNoFace(bool inForeground) {
    _signals?.add(AttentionSignals(
      facePresent: false,
      multiFace: false,
      appInForeground: inForeground,
    ));
  }

  void _emitIosStabilizedNoFace(bool inForeground) {
    final sig = _iosStabilizeFacePresent(
      AttentionSignals(
        facePresent: false,
        multiFace: false,
        appInForeground: inForeground,
      ),
    );
    _signals?.add(sig);
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
      if (_iosRawNoFaceStreak >= _iosFaceUnlatchFrames) {
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

  int get previewGeneration => _streamGeneration;

  Future<void> stop() async {
    await _stopInternal();
  }

  Future<void> _stopInternal() async {
    _running = false;
    _streamGeneration++;
    _frameSkip = 0;
    if (Platform.isIOS) {
      _iosRawFaceStreak = 0;
      _iosRawNoFaceStreak = 0;
      _iosLatchedFacePresent = false;
    }
    await _tearDownCameraOnly();
    await _detector?.dispose();
    _detector = null;
    final sc = _signals;
    _signals = null;
    await sc?.close();
    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _tearDownCameraOnly() async {
    final c = _controller;
    _controller = null;
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) {
        await c.stopImageStream();
      }
    } catch (e) {
      debugPrint('FaceAttentionSensor: stopImageStream → $e');
    }
    try {
      await c.dispose();
    } catch (e) {
      debugPrint('FaceAttentionSensor: dispose → $e');
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

    if (Platform.isIOS && !IosAttentionFacePipeline.isTrustworthyFace(face)) {
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
    if (h < 1e-6) return 0.0;
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
