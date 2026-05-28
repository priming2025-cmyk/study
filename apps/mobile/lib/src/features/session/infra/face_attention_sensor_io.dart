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
/// - **Android / macOS / iOS**: YUV(BGRA) + [startImageStream] + [rotationForFrame].
///   iOS는 [takePicture] 대신 스트림을 씁니다.
///
/// ### iOS (전 기종·OS 공통)
///
/// - [_detectIOS]: 여러 회전 후보 중 최고 점수 선택 (기종별 sensor 차이 흡수)
/// - [_iosStabilizeFacePresent]: 연속 2프레임 라치
/// - Android는 [_detectAndroid] 단일 회전 full 검출
class FaceAttentionSensor {
  FaceDetector? _detector;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  Timer? _heartbeatTimer;
  bool _running = false;
  bool _busy = false;
  int _streamGeneration = 0;

  // ── iOS 라치 관련 상태 ───────────────────────────────────────────────
  int _iosRawFaceStreak = 0;
  int _iosRawNoFaceStreak = 0;
  bool _iosLatchedFacePresent = false;

  DateTime? _lastValidSampleAt;
  DateTime? _lastEmitAt;
  CameraDescription? _activeCam;
  bool Function()? _activeAppInForeground;
  int _activeStreamGeneration = 0;

  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  /// 연속 N프레임 얼굴 감지 후 라치 ON.
  static const int _iosFaceLatchFrames = 2;

  /// 구형 iPhone에서 프레임당 검출이 길어질 수 있어 최소 간격을 둡니다.
  static const Duration _iosMinDetectInterval = Duration(milliseconds: 350);
  DateTime? _lastIosDetectStartedAt;

  /// 1 프레임만 얼굴 없으면 즉시 라치 OFF.
  static const int _iosFaceUnlatchFrames = 1;

  static const Duration _heartbeatInterval = Duration(milliseconds: 2000);
  static const Duration _iosHeartbeatInterval = Duration(milliseconds: 4500);

  /// [stop] 후 iOS AVCaptureSession이 완전히 해제되기까지 충분한 대기.
  static const Duration _iosPostStopDelay = Duration(milliseconds: 1500);

  /// 새 세션 시작 전 추가 안전 대기.
  static const Duration _iosPreStartDelay = Duration(milliseconds: 1000);

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
      await Future<void>.delayed(_iosPreStartDelay);
    }

    _running = true;
    final gen = ++_streamGeneration;
    _lastValidSampleAt = null;
    _lastEmitAt = null;
    _resetIosState();

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
      isIOS ? ResolutionPreset.low : ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: isMacOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();

    if (!_running || gen != _streamGeneration) {
      await _tearDownCameraOnly();
      return;
    }

    _emitSignal(AttentionSignals(
      facePresent: false,
      multiFace: false,
      appInForeground: appInForeground(),
    ));
    _startHeartbeat(appInForeground);

    _activeCam = cam;
    _activeAppInForeground = appInForeground;
    _activeStreamGeneration = gen;
    await _bindImageStream(cam: cam, appInForeground: appInForeground, gen: gen);
  }

  Future<void> _bindImageStream({
    required CameraDescription cam,
    required bool Function() appInForeground,
    required int gen,
  }) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || !_running || gen != _streamGeneration) {
      return;
    }

    final isMacOS = Platform.isMacOS;
    final isIOS = Platform.isIOS;

    await c.startImageStream((image) async {
      if (!_running || gen != _streamGeneration || _busy) return;

      if (isIOS) {
        final last = _lastIosDetectStartedAt;
        final now = DateTime.now();
        if (last != null && now.difference(last) < _iosMinDetectInterval) {
          return;
        }
        _lastIosDetectStartedAt = now;
      }

      _busy = true;
      try {
        final controller = _controller;
        if (controller == null || !controller.value.isInitialized) return;

        final List<Face> faces;
        if (isMacOS) {
          faces = await _detectMacOS(image);
        } else if (isIOS) {
          faces = await _detectIOS(
            image: image,
            cam: cam,
            reportedOrientation: controller.value.deviceOrientation,
          );
        } else {
          faces = await _detectAndroid(
            image: image,
            cam: cam,
            deviceOrientation: controller.value.deviceOrientation,
          );
        }

        var sig = _toSignals(
          faces,
          appInForeground(),
          strictIos: isIOS,
        );
        if (isIOS) {
          sig = _iosStabilizeFacePresent(sig);
        }
        if (sig.facePresent) _lastValidSampleAt = DateTime.now();
        _emitSignal(sig);
      } catch (e) {
        debugPrint('FaceAttentionSensor: 감지 오류 → $e');
        if (isIOS) {
          _emitIosStabilizedNoFace(appInForeground());
        } else {
          _emitNoFace(appInForeground());
        }
      } finally {
        _busy = false;
      }
    });
  }

  /// 스터디방 1분 스냅샷: 이미지 스트림을 잠시 멈추고 JPEG 캡처 후 재개합니다.
  Future<Uint8List?> captureSnapshotJpeg() async {
    if (!_running) return null;
    final c = _controller;
    final cam = _activeCam;
    final appFg = _activeAppInForeground;
    final gen = _activeStreamGeneration;
    if (c == null || cam == null || appFg == null || !c.value.isInitialized) {
      return null;
    }

    final wasStreaming = c.value.isStreamingImages;
    try {
      if (wasStreaming) {
        await c.stopImageStream();
        if (Platform.isIOS) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
      final xfile = await c.takePicture();
      return await xfile.readAsBytes();
    } catch (e) {
      debugPrint('FaceAttentionSensor: captureSnapshotJpeg → $e');
      return null;
    } finally {
      if (wasStreaming && _running && gen == _streamGeneration && c == _controller) {
        try {
          await _bindImageStream(cam: cam, appInForeground: appFg, gen: gen);
        } catch (e) {
          debugPrint('FaceAttentionSensor: resume stream → $e');
        }
      }
    }
  }

  /// 2.5초 MP4 원본 녹화 (이미지 스트림 일시 중지).
  Future<String?> captureStudyClipPath() async {
    if (!_running) return null;
    final c = _controller;
    final cam = _activeCam;
    final appFg = _activeAppInForeground;
    final gen = _activeStreamGeneration;
    if (c == null || cam == null || appFg == null || !c.value.isInitialized) {
      return null;
    }
    if (c.value.isRecordingVideo) return null;

    final wasStreaming = c.value.isStreamingImages;
    try {
      if (wasStreaming) {
        await c.stopImageStream();
        if (Platform.isIOS) {
          await Future<void>.delayed(const Duration(milliseconds: 280));
        }
      }
      await c.startVideoRecording();
      await Future<void>.delayed(
        const Duration(milliseconds: 2600),
      );
      final xfile = await c.stopVideoRecording();
      return xfile.path;
    } catch (e) {
      debugPrint('FaceAttentionSensor: captureStudyClipPath → $e');
      return null;
    } finally {
      if (wasStreaming && _running && gen == _streamGeneration && c == _controller) {
        try {
          await _bindImageStream(cam: cam, appInForeground: appFg, gen: gen);
        } catch (e) {
          debugPrint('FaceAttentionSensor: resume stream after clip → $e');
        }
      }
    }
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

  /// iOS: 회전 후보마다 fast→full 후 **최고 점수** 채택 (기종·OS별 버퍼 차이 대응).
  Future<List<Face>> _detectIOS({
    required CameraImage image,
    required CameraDescription cam,
    required DeviceOrientation reportedOrientation,
  }) async {
    if (!IosAttentionFacePipeline.frameLooksLikeLiveCamera(image)) {
      return const [];
    }

    final detector = _detector;
    if (detector == null) return const [];

    final rotations = IosAttentionFacePipeline.rotationCandidates(
      cam: cam,
      image: image,
      reportedOrientation: reportedOrientation,
    );

    List<Face> bestFaces = const [];
    var bestRank = 0.0;

    Future<List<Face>> detectAt(
      CameraFrameRotation? rotation,
      FaceDetectionMode mode,
    ) {
      return detector
          .detectFacesFromCameraImage(
            image,
            rotation: rotation,
            isBgra: false,
            mode: mode,
            maxDim: 320,
          )
          .timeout(const Duration(milliseconds: 1800));
    }

    for (final rotation in rotations) {
      List<Face> fast;
      try {
        fast = await detectAt(rotation, FaceDetectionMode.fast);
      } catch (_) {
        continue;
      }
      final gated =
          fast.where(IosAttentionFacePipeline.passesFastGate).toList();
      if (gated.isEmpty) continue;

      List<Face> full;
      try {
        full = await detectAt(rotation, FaceDetectionMode.full);
      } catch (_) {
        continue;
      }

      final trusted = IosAttentionFacePipeline.filterTrustworthy(
        full,
        requireFastOverlap: gated,
      );
      if (trusted.isEmpty) continue;

      final top = trusted.first;
      final rank = IosAttentionFacePipeline.rankFace(top);
      if (rank > bestRank) {
        bestRank = rank;
        bestFaces = trusted;
      }
      if (rank >= 0.92) break;
    }

    return bestFaces;
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

  void _startHeartbeat(bool Function() appInForeground) {
    _heartbeatTimer?.cancel();
    final interval =
        Platform.isIOS ? _iosHeartbeatInterval : _heartbeatInterval;
    _heartbeatTimer = Timer.periodic(interval, (_) {
      if (!_running) return;
      final last = _lastEmitAt;
      if (last == null || DateTime.now().difference(last) > interval) {
        // iOS는 라치 상태를 유지하며 '없음' 신호를보냅니다.
        if (Platform.isIOS) {
          _emitIosStabilizedNoFace(appInForeground());
        } else {
          _emitNoFace(appInForeground());
        }
      }
    });
  }

  void _emitSignal(AttentionSignals s) {
    _lastEmitAt = DateTime.now();
    _signals?.add(s);
  }

  void _emitNoFace(bool inForeground) {
    _emitSignal(AttentionSignals(
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
    _emitSignal(sig);
  }

  // ── iOS 라치 + 생물학적 EAR 변화 검사 ────────────────────────────────

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
        earLeft: raw.earLeft,
        earRight: raw.earRight,
        headYaw: raw.headYaw,
        headPitch: raw.headPitch,
        blinkFrame: raw.blinkFrame,
      );
    }
    return raw;
  }

  void _resetIosState() {
    _iosRawFaceStreak = 0;
    _iosRawNoFaceStreak = 0;
    _iosLatchedFacePresent = false;
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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastValidSampleAt = null;
    _lastEmitAt = null;
    _lastIosDetectStartedAt = null;
    _activeCam = null;
    _activeAppInForeground = null;
    _activeStreamGeneration = 0;
    _resetIosState();

    await _tearDownCameraOnly();
    await _detector?.dispose();
    _detector = null;
    final sc = _signals;
    _signals = null;
    await sc?.close();
    if (Platform.isIOS) {
      // AVFoundation이 다음 세션을 위해 자원을 완전히 풀 시간을 줍니다.
      await Future<void>.delayed(_iosPostStopDelay);
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

    if (strictIos) {
      if (!IosAttentionFacePipeline.earsPlausible(earL, earR) ||
          face.detectionData.score < 0.72) {
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

      final faceHeight =
          (chin.y - eyeCy).abs().clamp(1.0, double.infinity);
      final pitchRatio = (nose.y - eyeCy) / faceHeight;
      final pitch = (pitchRatio - 0.35) * 120.0;

      return (yaw, pitch);
    } catch (_) {
      return (0.0, 0.0);
    }
  }
}
