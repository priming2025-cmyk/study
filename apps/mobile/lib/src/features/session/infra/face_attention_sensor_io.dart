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
/// - **Android / macOS**: YUV(BGRA) + [startImageStream] + [rotationForFrame].
/// - **iOS**: **프리뷰만** + 주기 [takePicture] JPEG 검출.
///   (스트림+프리뷰 동시 사용 시 검은 화면·2회차 실패·빈 화면 오검이 잦음)
class FaceAttentionSensor {
  FaceDetector? _detector;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  Timer? _iosSampleTimer;
  bool _running = false;
  bool _busy = false;
  int _streamGeneration = 0;

  int _iosRawFaceStreak = 0;
  int _iosRawNoFaceStreak = 0;
  bool _iosLatchedFacePresent = false;
  DateTime? _lastValidSampleAt;
  double? _iosLastEarL;
  double? _iosLastEarR;
  int _iosSameEarStreak = 0;

  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  static const int _iosFaceLatchFrames = 4;
  static const int _iosFaceUnlatchFrames = 1;

  FaceAttentionSensor();

  bool get isCameraReady =>
      _running &&
      _controller != null &&
      (_controller?.value.isInitialized ?? false);

  bool get hasRecentValidSample {
    final t = _lastValidSampleAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(seconds: 3);
  }

  Future<void> start({
    CameraDescription? camera,
    required bool Function() appInForeground,
    bool skipCameraEnumeration = false,
  }) async {
    final cam = camera;
    if (cam == null) throw StateError('카메라가 필요합니다.');

    await stop();
    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    _running = true;
    final gen = ++_streamGeneration;
    _lastValidSampleAt = null;

    if (Platform.isIOS) {
      _iosRawFaceStreak = 0;
      _iosRawNoFaceStreak = 0;
      _iosLatchedFacePresent = false;
      _iosLastEarL = null;
      _iosLastEarR = null;
      _iosSameEarStreak = 0;
    }

    _signals = StreamController<AttentionSignals>.broadcast();

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
      isIOS ? ResolutionPreset.medium : ResolutionPreset.medium,
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

    if (isIOS) {
      _iosSampleTimer?.cancel();
      _iosSampleTimer = Timer.periodic(
        const Duration(milliseconds: 800),
        (_) => unawaited(_iosSampleOnce(cam, appInForeground, gen)),
      );
      unawaited(_iosSampleOnce(cam, appInForeground, gen));
      return;
    }

    await _controller!.startImageStream((image) async {
      if (!_running || _busy || gen != _streamGeneration) return;

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

        final sig = _toSignals(faces, appInForeground());
        _markSample(sig.facePresent);
        _signals?.add(sig);
      } catch (e) {
        debugPrint('FaceAttentionSensor: 감지 오류 → $e');
        _emitNoFace(appInForeground());
      } finally {
        _busy = false;
      }
    });
  }

  Future<void> _iosSampleOnce(
    CameraDescription cam,
    bool Function() appInForeground,
    int gen,
  ) async {
    if (!_running || _busy || gen != _streamGeneration) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    _busy = true;
    try {
      final file = await c.takePicture();
      final bytes = await File(file.path).readAsBytes();
      try {
        await File(file.path).delete();
      } catch (_) {}

      if (!_running || gen != _streamGeneration) return;

      final faces = await _detectIOSFromJpeg(bytes);
      var sig = _toSignals(faces, appInForeground());
      sig = _iosRejectSyntheticMesh(sig);
      sig = _iosStabilizeFacePresent(sig);
      if (sig.facePresent) {
        _lastValidSampleAt = DateTime.now();
      }
      _signals?.add(sig);
    } catch (e) {
      debugPrint('FaceAttentionSensor[iOS]: 샘플 실패 → $e');
      _emitIosStabilizedNoFace(appInForeground());
    } finally {
      _busy = false;
    }
  }

  Future<List<Face>> _detectIOSFromJpeg(List<int> bytes) async {
    final data = bytes is Uint8List
        ? bytes
        : Uint8List.fromList(bytes);
    if (!IosAttentionFacePipeline.jpegLooksLikePhoto(data)) {
      return const [];
    }

    final fast = await _detector!
        .detectFaces(data, mode: FaceDetectionMode.fast)
        .timeout(const Duration(milliseconds: 1500));
    final fastOk = fast.where(IosAttentionFacePipeline.passesFastGate).toList();
    if (fastOk.isEmpty) return const [];

    final full = await _detector!
        .detectFaces(data, mode: FaceDetectionMode.full)
        .timeout(const Duration(milliseconds: 2000));

    return IosAttentionFacePipeline.filterTrustworthy(
      full,
      requireFastOverlap: fastOk,
    );
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

  void _markSample(bool facePresent) {
    if (facePresent) {
      _lastValidSampleAt = DateTime.now();
    }
  }

  void _emitNoFace(bool inForeground) {
    _signals?.add(AttentionSignals(
      facePresent: false,
      multiFace: false,
      appInForeground: inForeground,
    ));
  }

  /// iOS 오검 mesh는 프레임마다 EAR이 완전히 동일한 경우가 많습니다.
  AttentionSignals _iosRejectSyntheticMesh(AttentionSignals raw) {
    if (!raw.facePresent) {
      _iosSameEarStreak = 0;
      _iosLastEarL = null;
      _iosLastEarR = null;
      return raw;
    }
    final same = _iosLastEarL == raw.earLeft &&
        _iosLastEarR == raw.earRight &&
        _iosLastEarL != null;
    if (same) {
      _iosSameEarStreak++;
    } else {
      _iosSameEarStreak = 0;
    }
    _iosLastEarL = raw.earLeft;
    _iosLastEarR = raw.earRight;
    if (_iosSameEarStreak >= 4) {
      return AttentionSignals(
        facePresent: false,
        multiFace: false,
        appInForeground: raw.appInForeground,
      );
    }
    return raw;
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
    _iosSampleTimer?.cancel();
    _iosSampleTimer = null;
    _lastValidSampleAt = null;
    if (Platform.isIOS) {
      _iosRawFaceStreak = 0;
      _iosRawNoFaceStreak = 0;
      _iosLatchedFacePresent = false;
      _iosLastEarL = null;
      _iosLastEarR = null;
      _iosSameEarStreak = 0;
    }
    await _tearDownCameraOnly();
    await _detector?.dispose();
    _detector = null;
    final sc = _signals;
    _signals = null;
    await sc?.close();
    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
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

    if (Platform.isIOS) {
      if (!IosAttentionFacePipeline.earsPlausible(earL, earR)) {
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
