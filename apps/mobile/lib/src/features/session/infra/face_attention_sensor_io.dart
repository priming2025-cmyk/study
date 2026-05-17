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
///
/// ### iOS 오검 방어 레이어 (4단계)
///
/// 1. [IosAttentionFacePipeline.jpegLooksLikePhoto] — 어두운/단색 JPEG 사전 차단
/// 2. [IosAttentionFacePipeline.passesFastGate] / [filterTrustworthy]
///    — 낮은 점수·작은 얼굴 차단
/// 3. [_iosStabilizeFacePresent] — 짧은 오검은 무시, 연속 N프레임만 라치
/// 4. **생물학적 EAR 변화 요건** — 라치 전 EAR 범위 ≥ 0.020 (진짜 얼굴만 통과)
///    포스터·모니터·환각은 EAR이 거의 고정이므로 이 조건을 충족하지 못합니다.
class FaceAttentionSensor {
  FaceDetector? _detector;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  Timer? _iosSampleTimer;
  Timer? _heartbeatTimer;
  bool _running = false;
  bool _busy = false;
  int _streamGeneration = 0;

  // ── iOS 라치 관련 상태 ───────────────────────────────────────────────
  int _iosRawFaceStreak = 0;
  int _iosRawNoFaceStreak = 0;
  bool _iosLatchedFacePresent = false;

  /// 라치 윈도우 안의 EAR 샘플 (생물학적 변화 검사용).
  final List<double> _iosEarLHistory = [];
  final List<double> _iosEarRHistory = [];

  DateTime? _lastValidSampleAt;
  DateTime? _lastEmitAt;

  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

  /// 연속 N프레임 얼굴 감지 후 라치 ON.
  /// N × _iosSampleInterval ≈ 6 × 1200ms = 7.2초.
  static const int _iosFaceLatchFrames = 6;

  /// 1 프레임만 얼굴 없으면 즉시 라치 OFF.
  static const int _iosFaceUnlatchFrames = 1;

  /// 라치 전 최소 EAR 변화 범위.
  /// - 진짜 사람: 호흡·미세 근육으로 0.03~0.10 변화 → 통과
  /// - 포스터·모니터·환각: 모델 노이즈 수준 0.001~0.008 → 차단
  static const double _iosEarVarianceMin = 0.020;

  static const Duration _iosSampleInterval = Duration(milliseconds: 1200);
  static const Duration _heartbeatInterval = Duration(milliseconds: 2000);

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

    _emitSignal(AttentionSignals(
      facePresent: false,
      multiFace: false,
      appInForeground: appInForeground(),
    ));
    _startHeartbeat(appInForeground);

    if (isIOS) {
      _iosSampleTimer?.cancel();
      // periodic 대신 "끝나면 다음 예약" 방식으로 busy 충돌을 방지합니다.
      unawaited(_iosScheduleNext(cam, appInForeground, gen));
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
        if (sig.facePresent) _lastValidSampleAt = DateTime.now();
        _emitSignal(sig);
      } catch (e) {
        debugPrint('FaceAttentionSensor: 감지 오류 → $e');
        _emitNoFace(appInForeground());
      } finally {
        _busy = false;
      }
    });
  }

  /// iOS 샘플을 직렬(순서대로) 처리합니다.
  /// Timer.periodic과 달리 이전 샘플이 끝나야 다음이 시작되므로 _busy 경합이 없습니다.
  Future<void> _iosScheduleNext(
    CameraDescription cam,
    bool Function() appInForeground,
    int gen,
  ) async {
    while (_running && gen == _streamGeneration) {
      await _iosSampleOnce(cam, appInForeground, gen);
      if (_running && gen == _streamGeneration) {
        await Future<void>.delayed(_iosSampleInterval);
      }
    }
  }

  Future<void> _iosSampleOnce(
    CameraDescription cam,
    bool Function() appInForeground,
    int gen,
  ) async {
    if (!_running || gen != _streamGeneration) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    try {
      final file = await c.takePicture();
      final bytes = await File(file.path).readAsBytes();
      try {
        await File(file.path).delete();
      } catch (_) {}

      if (!_running || gen != _streamGeneration) return;

      final faces = await _detectIOSFromJpeg(bytes);
      var sig = _toSignals(faces, appInForeground());
      sig = _iosStabilizeFacePresent(sig);
      if (sig.facePresent) {
        _lastValidSampleAt = DateTime.now();
      }
      _emitSignal(sig);
    } catch (e) {
      debugPrint('FaceAttentionSensor[iOS]: 샘플 실패 → $e');
      _emitIosStabilizedNoFace(appInForeground());
    }
  }

  Future<List<Face>> _detectIOSFromJpeg(List<int> bytes) async {
    final data =
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    if (!IosAttentionFacePipeline.jpegLooksLikePhoto(data)) {
      return const [];
    }

    final fast = await _detector!
        .detectFaces(data, mode: FaceDetectionMode.fast)
        .timeout(const Duration(milliseconds: 1500));
    final fastOk =
        fast.where(IosAttentionFacePipeline.passesFastGate).toList();
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
    if (isMacOS) return _detectMacOS(image);

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

  void _startHeartbeat(bool Function() appInForeground) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (!_running) return;
      final last = _lastEmitAt;
      if (last == null ||
          DateTime.now().difference(last) > _heartbeatInterval) {
        // 감지가 멈추면 '얼굴 없음'을 흘려 라치가 굳지 않게 합니다.
        _emitNoFace(appInForeground());
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

      // 라치 윈도우 안의 EAR 이력 누적
      _iosEarLHistory.add(raw.earLeft);
      _iosEarRHistory.add(raw.earRight);
      if (_iosEarLHistory.length > _iosFaceLatchFrames) {
        _iosEarLHistory.removeAt(0);
        _iosEarRHistory.removeAt(0);
      }

      if (_iosRawFaceStreak >= _iosFaceLatchFrames) {
        // ★ 생물학적 EAR 변화 검사 ★
        // 진짜 사람: 호흡·미세 근육으로 EAR 범위 0.03+ → 통과
        // 포스터·화면·환각: 모델 노이즈 0.001~0.008 → 차단
        if (_iosEarHasSufficientVariance()) {
          _iosLatchedFacePresent = true;
        }
        // 변화 부족하면 streak은 계속 세지만 라치는 하지 않음
      }
    } else {
      _iosRawNoFaceStreak++;
      _iosRawFaceStreak = 0;
      _iosEarLHistory.clear();
      _iosEarRHistory.clear();
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

  /// 라치 윈도우 안에서 EAR이 충분히 변화했는지 검사합니다.
  ///
  /// 진짜 사람은 약 4~7초 안에 호흡·미세 근육으로 반드시 0.020 이상 변화합니다.
  /// 포스터·모니터·환각은 모델 노이즈 수준(0.001~0.008)만 변하므로 차단됩니다.
  bool _iosEarHasSufficientVariance() {
    if (_iosEarLHistory.length < _iosFaceLatchFrames) return false;
    var minL = _iosEarLHistory[0];
    var maxL = _iosEarLHistory[0];
    var minR = _iosEarRHistory[0];
    var maxR = _iosEarRHistory[0];
    for (final v in _iosEarLHistory) {
      if (v < minL) minL = v;
      if (v > maxL) maxL = v;
    }
    for (final v in _iosEarRHistory) {
      if (v < minR) minR = v;
      if (v > maxR) maxR = v;
    }
    return (maxL - minL) >= _iosEarVarianceMin ||
        (maxR - minR) >= _iosEarVarianceMin;
  }

  void _resetIosState() {
    _iosRawFaceStreak = 0;
    _iosRawNoFaceStreak = 0;
    _iosLatchedFacePresent = false;
    _iosEarLHistory.clear();
    _iosEarRHistory.clear();
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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastValidSampleAt = null;
    _lastEmitAt = null;
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

    if (Platform.isIOS && !IosAttentionFacePipeline.earsPlausible(earL, earR)) {
      return AttentionSignals(
        facePresent: false,
        multiFace: false,
        appInForeground: inForeground,
      );
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
