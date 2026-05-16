import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import '../domain/attention_signals.dart';
import 'camera_exclusive_gate.dart';
import 'ios_attention_face_pipeline.dart';

/// 앱(iOS·Android·macOS)용 얼굴 집중도 센서.
///
/// - **Android**: YUV420 + 이미지 스트림 + [rotationForFrame].
/// - **iOS**: **프리뷰만** 켜고 `takePicture` JPEG로 주기 검출 (스트림+프리뷰 동시 사용 시
///   검은 화면·2회차 실패·빈 화면 오검이 잦음).
/// - **macOS**: BGRA + `prepareCameraFrame`.
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

  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  static const int _iosFaceLatchFrames = 3;

  FaceAttentionSensor();

  Future<void> start({
    CameraDescription? camera,
    required bool Function() appInForeground,
    bool skipCameraEnumeration = false,
  }) async {
    final cam = camera;
    if (cam == null) throw StateError('카메라가 필요합니다.');

    await CameraExclusiveGate.claim(
      holder: this,
      release: () => _stopInternal(),
    );

    _running = true;
    final gen = ++_streamGeneration;

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
    final isIOS = Platform.isIOS;

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

    if (isIOS) {
      _iosSampleTimer?.cancel();
      _iosSampleTimer = Timer.periodic(
        const Duration(milliseconds: 900),
        (_) => unawaited(_iosSampleOnce(cam, appInForeground, gen)),
      );
      unawaited(_iosSampleOnce(cam, appInForeground, gen));
    } else {
      await _controller!.startImageStream((image) async {
        if (!_running || _busy || gen != _streamGeneration) return;
        _busy = true;
        try {
          final controller = _controller;
          if (controller == null || !controller.value.isInitialized) return;

          List<Face> faces;
          if (isMacOS) {
            faces = await _detectMacOS(image);
          } else {
            faces = await _detectAndroid(
              image: image,
              cam: cam,
              deviceOrientation: controller.value.deviceOrientation,
            );
          }

          _signals?.add(_toSignals(faces, appInForeground()));
        } catch (e) {
          debugPrint('FaceAttentionSensor: 감지 오류 → $e');
          _emitNoFace(appInForeground());
        } finally {
          _busy = false;
        }
      });
    }
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

      final faces = await _detectIOSFromJpeg(bytes);
      var sig = _toSignals(faces, appInForeground(), strictIos: true);
      sig = _iosStabilizeFacePresent(sig);
      _signals?.add(sig);
    } catch (e) {
      debugPrint('FaceAttentionSensor[iOS]: 샘플 실패 → $e');
      _emitNoFace(appInForeground());
    } finally {
      _busy = false;
    }
  }

  Future<List<Face>> _detectIOSFromJpeg(List<int> bytes) async {
    final faces = await _detector!
        .detectFaces(
          bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          mode: FaceDetectionMode.full,
        )
        .timeout(const Duration(milliseconds: 2000));
    return IosAttentionFacePipeline.filterTrustworthy(faces);
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
    await CameraExclusiveGate.release(this);
  }

  Future<void> _stopInternal() async {
    _running = false;
    _streamGeneration++;
    _iosSampleTimer?.cancel();
    _iosSampleTimer = null;
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
          face.detectionData.score < 0.85) {
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
