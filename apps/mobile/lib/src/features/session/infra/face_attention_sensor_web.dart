import 'dart:async';
import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart' show Uint8List, debugPrint;

import '../domain/attention_signals.dart';
import 'web_attention_face_codec.dart';

/// 웹(Flutter Web)용 얼굴 집중 센서 — [AttentionCameraService] 경로.
///
/// 공부 세션·스터디방의 주 경로는 [SessionSelfCameraSurface] 입니다.
/// 이 클래스는 보조 경로이며, 카메라 실패 시 **절대** `facePresent: true` 를 내지 않습니다.
class FaceAttentionSensor {
  FaceDetector? _detector;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  Timer? _timer;
  bool _running = false;
  bool _busy = false;
  int _streamGeneration = 0;
  DateTime? _lastValidSampleAt;
  final WebAttentionFacePipeline _pipeline = WebAttentionFacePipeline();

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

  int get previewGeneration => _streamGeneration;

  Future<void> start({
    CameraDescription? camera,
    required bool Function() appInForeground,
    bool skipCameraEnumeration = false,
  }) async {
    if (_running) return;
    _running = true;
    _streamGeneration++;
    _lastValidSampleAt = null;
    _pipeline.reset();
    _signals = StreamController<AttentionSignals>.broadcast();

    if (skipCameraEnumeration && camera == null) {
      debugPrint('[FaceAttentionSensor-Web] 미리보기 전용 → 얼굴 없음 신호');
      _emitNoFace(appInForeground);
      return;
    }

    CameraDescription? cam = camera;
    if (cam == null) {
      try {
        final cams = await availableCameras();
        if (cams.isEmpty) {
          debugPrint('[FaceAttentionSensor-Web] 카메라 없음');
          _emitNoFace(appInForeground);
          return;
        }
        final front = cams
            .where((c) => c.lensDirection == CameraLensDirection.front)
            .toList();
        cam = front.isNotEmpty ? front.first : cams.first;
      } catch (e) {
        debugPrint('[FaceAttentionSensor-Web] availableCameras 실패: $e');
        _emitNoFace(appInForeground);
        return;
      }
    }

    try {
      _detector = FaceDetector();
      await _detector!.initialize(model: FaceDetectionModel.frontCamera);

      _controller = CameraController(
        cam,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await _controller!.initialize();

      unawaited(_sampleLoop(appInForeground));
    } catch (e) {
      debugPrint('[FaceAttentionSensor-Web] 초기화 실패: $e');
      await _detector?.dispose();
      _detector = null;
      _emitNoFace(appInForeground);
    }
  }

  Future<void> _sampleLoop(bool Function() appInForeground) async {
    while (_running) {
      if (!_busy && _controller != null) {
        await _sampleOnce(appInForeground);
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
  }

  Future<void> _sampleOnce(bool Function() appInForeground) async {
    if (!_running || _busy || _controller == null) return;
    _busy = true;
    try {
      final xfile = await _controller!.takePicture();
      final bytes = await xfile.readAsBytes();
      final data = Uint8List.fromList(bytes);

      if (!WebAttentionFacePipeline.jpegLooksLikePhoto(data)) {
        _emitNoFace(appInForeground);
        return;
      }

      final fast = await _detector!
          .detectFaces(data, mode: FaceDetectionMode.fast);
      final fastOk =
          fast.where(WebAttentionFacePipeline.passesFastGate).toList();
      if (fastOk.isEmpty) {
        _emitNoFace(appInForeground);
        return;
      }

      final full = await _detector!
          .detectFaces(data, mode: FaceDetectionMode.full);
      final trusted = WebAttentionFacePipeline.filterTrustworthy(
        full,
        requireFastOverlap: fastOk,
      );

      final sig = _pipeline.processFaces(trusted, appInForeground());
      if (sig.facePresent) _lastValidSampleAt = DateTime.now();
      _signals?.add(sig);
    } catch (e) {
      debugPrint('[FaceAttentionSensor-Web] 감지 오류: $e');
      _emitNoFace(appInForeground);
    } finally {
      _busy = false;
    }
  }

  void _emitNoFace(bool Function() appInForeground) {
    _signals?.add(_pipeline.noFace(appInForeground()));
  }

  Stream<AttentionSignals> get stream =>
      _signals?.stream ?? const Stream.empty();

  CameraController? get controller => _controller;

  Future<void> stop() async {
    _running = false;
    _streamGeneration++;
    _lastValidSampleAt = null;
    _pipeline.reset();
    _timer?.cancel();
    _timer = null;
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    await _detector?.dispose();
    _detector = null;
    await _signals?.close();
    _signals = null;
  }
}
