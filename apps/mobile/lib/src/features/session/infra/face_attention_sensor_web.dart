import 'dart:async';

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart' show Uint8List, debugPrint;

import '../domain/attention_signals.dart';
import 'web_attention_face_codec.dart';
import 'web_face_detector_holder.dart';

/// 웹(Flutter Web)용 얼굴 집중 센서 — [AttentionCameraService] 보조 경로.
///
/// 주 경로는 [SessionSelfCameraSurface]. 카메라 실패 시 **절대** `facePresent: true` 를 내지 않습니다.
class FaceAttentionSensor {
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
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
      _emitNoFace(appInForeground);
      return;
    }

    CameraDescription? cam = camera;
    if (cam == null) {
      try {
        final cams = await availableCameras();
        if (cams.isEmpty) {
          _emitNoFace(appInForeground);
          return;
        }
        final front = cams
            .where((c) => c.lensDirection == CameraLensDirection.front)
            .toList();
        cam = front.isNotEmpty ? front.first : cams.first;
      } catch (e) {
        debugPrint('[FaceAttentionSensor-Web] cameras: $e');
        _emitNoFace(appInForeground);
        return;
      }
    }

    try {
      _controller = CameraController(
        cam,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await _controller!.initialize();
      unawaited(_sampleLoop(appInForeground));
    } catch (e) {
      debugPrint('[FaceAttentionSensor-Web] camera: $e');
      _emitNoFace(appInForeground);
    }
  }

  Future<void> _sampleLoop(bool Function() appInForeground) async {
    while (_running) {
      if (!_busy) {
        await _sampleOnce(appInForeground);
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
  }

  Future<void> _sampleOnce(bool Function() appInForeground) async {
    if (!_running || _busy || _controller == null) return;
    _busy = true;
    try {
      final det = await WebFaceDetectorHolder.instance.acquire();
      if (det == null) {
        _emitNoFace(appInForeground);
        return;
      }

      final xfile = await _controller!.takePicture();
      final bytes = await xfile.readAsBytes();
      final data = Uint8List.fromList(bytes);

      if (!WebAttentionFacePipeline.jpegLooksLikePhoto(data)) {
        _emitNoFace(appInForeground);
        return;
      }

      final fast = await det.detectFaces(data, mode: FaceDetectionMode.fast);
      final fastOk =
          fast.where(WebAttentionFacePipeline.passesFastGate).toList();
      if (fastOk.isEmpty) {
        _emitNoFace(appInForeground);
        return;
      }

      final full = await det.detectFaces(data, mode: FaceDetectionMode.full);
      final trusted = WebAttentionFacePipeline.filterTrustworthy(
        full,
        requireFastOverlap: fastOk,
      );

      final sig = _pipeline.processFaces(trusted, appInForeground());
      if (sig.facePresent) _lastValidSampleAt = DateTime.now();
      _signals?.add(sig);
    } catch (e) {
      debugPrint('[FaceAttentionSensor-Web] sample: $e');
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
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    await _signals?.close();
    _signals = null;
  }
}
