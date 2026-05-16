import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import '../domain/attention_signals.dart';
import 'ios_attention_face_pipeline.dart';

/// 앱(iOS·Android·macOS)용 얼굴 집중도 센서.
///
/// - **Android / iOS**: YUV420 + [rotationForFrame] + `detectFacesFromCameraImage`
///   (공식 예제와 동일). iOS만 fast→full 2단계 + [IosAttentionFacePipeline] 검증.
/// - **macOS**: BGRA + `prepareCameraFrame`.
class FaceAttentionSensor {
  FaceDetector? _detector;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  bool _running = false;
  bool _busy = false;
  int _streamGeneration = 0;

  int _iosRawFaceStreak = 0;
  int _iosRawNoFaceStreak = 0;
  bool _iosLatchedFacePresent = false;

  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  static const int _iosFaceLatchFrames = 4;

  FaceAttentionSensor();

  Future<void> start({
    CameraDescription? camera,
    required bool Function() appInForeground,
    bool skipCameraEnumeration = false,
  }) async {
    final cam = camera;
    if (cam == null) throw StateError('카메라가 필요합니다.');

    // 이전 세션 카메라·스트림이 남으면 iOS에서 2회차 검은 화면·오검이 잦음.
    await stop();

    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    _running = true;
    final gen = ++_streamGeneration;

    _signals = StreamController<AttentionSignals>.broadcast();
    _emitNoFace(appInForeground());

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
    final isIOS = Platform.isIOS;

    _controller = CameraController(
      cam,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup:
          isMacOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();

    if (!_running || gen != _streamGeneration) {
      await _tearDownCameraOnly();
      return;
    }

    await _controller!.startImageStream((image) async {
      if (!_running || _busy || gen != _streamGeneration) return;
      _busy = true;
      try {
        final controller = _controller;
        if (controller == null || !controller.value.isInitialized) {
          return;
        }

        List<Face> faces;

        if (isMacOS) {
          faces = await _detectMacOS(image);
        } else if (isIOS) {
          faces = await _detectIOS(image: image, cam: cam);
        } else {
          faces = await _detectAndroid(
            image: image,
            cam: cam,
            deviceOrientation: controller.value.deviceOrientation,
          );
        }

        var sig = _toSignals(faces, appInForeground(), strictIos: isIOS);
        if (isIOS) {
          sig = _iosStabilizeFacePresent(sig);
        }
        _signals?.add(sig);
      } catch (e) {
        debugPrint('FaceAttentionSensor: 감지 오류 → $e');
        _emitNoFace(appInForeground());
      } finally {
        _busy = false;
      }
    });
  }

  void _emitNoFace(bool inForeground) {
    _signals?.add(AttentionSignals(
      facePresent: false,
      multiFace: false,
      appInForeground: inForeground,
    ));
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

  Future<List<Face>> _detectAndroid({
    required CameraImage image,
    required CameraDescription cam,
    required DeviceOrientation deviceOrientation,
  }) async {
    final rotation = rotationForFrame(
      width: image.width,
      height: image.height,
      sensorOrientation: cam.sensorOrientation,
      isFrontCamera: cam.lensDirection == CameraLensDirection.front,
      deviceOrientation: deviceOrientation,
    );
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

  /// iOS: YUV + [rotationForFrame]. 집중 앱은 세로 고정 → portraitUp으로 회전 안정화.
  /// fast 1차 통과 시 다른 회전에서도 얼굴이 잡히면 빈 장면 오검으로 보고 무시.
  Future<List<Face>> _detectIOS({
    required CameraImage image,
    required CameraDescription cam,
  }) async {
    if (!IosAttentionFacePipeline.frameLooksLikeLiveCamera(image)) {
      return const [];
    }

    // iOS 스트림 초기에 deviceOrientation이 어긋나 회전이 틀어지는 경우가 많음.
    const orient = DeviceOrientation.portraitUp;
    final rotation = rotationForFrame(
      width: image.width,
      height: image.height,
      sensorOrientation: cam.sensorOrientation,
      isFrontCamera: cam.lensDirection == CameraLensDirection.front,
      deviceOrientation: orient,
    );

    Future<List<Face>> fastAt(CameraFrameRotation? r) => _detector!
        .detectFacesFromCameraImage(
          image,
          rotation: r,
          isBgra: false,
          mode: FaceDetectionMode.fast,
          maxDim: 320,
        )
        .timeout(const Duration(milliseconds: 1200));

    final primaryFast =
        (await fastAt(rotation)).where(IosAttentionFacePipeline.passesFastGate);
    if (primaryFast.isEmpty) return const [];

    for (final alt in <CameraFrameRotation?>[
      null,
      CameraFrameRotation.cw90,
      CameraFrameRotation.cw270,
    ]) {
      if (alt == rotation) continue;
      final altHits =
          (await fastAt(alt)).where(IosAttentionFacePipeline.passesFastGate);
      if (altHits.isNotEmpty) return const [];
    }

    final full = await _detector!
        .detectFacesFromCameraImage(
          image,
          rotation: rotation,
          isBgra: false,
          mode: FaceDetectionMode.full,
          maxDim: 320,
        )
        .timeout(const Duration(milliseconds: 1500));

    return IosAttentionFacePipeline.filterTrustworthy(full);
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

  int get previewGeneration => _streamGeneration;

  Future<void> stop() async {
    _running = false;
    _streamGeneration++;
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

  AttentionSignals _toSignals(
    List<Face> faces,
    bool inForeground, {
    bool strictIos = false,
  }) {
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
    if (strictIos || Platform.isIOS) {
      if (earL < 0.14 ||
          earR < 0.14 ||
          earL > 0.45 ||
          earR > 0.45 ||
          face.detectionData.score < 0.82) {
        return AttentionSignals(
          facePresent: false,
          multiFace: false,
          appInForeground: inForeground,
        );
      }
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
