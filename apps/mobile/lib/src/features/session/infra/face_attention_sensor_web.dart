import 'dart:async';
import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';

import '../domain/attention_signals.dart';
import 'web_attention_face_codec.dart';

/// 웹(Flutter Web)용 얼굴 집중도 센서.
///
/// face_detection_tflite 의 웹 구현(WASM/TFLite.js)은 [FaceDetector.detectFaces]
/// 만 지원합니다(detectFacesFromCameraImage 는 웹 미지원).
/// 따라서 500ms 간격으로 [CameraController.takePicture] → JPEG 바이트를
/// detectFaces 에 전달해 468-point mesh 기반 EAR·머리 방향을 계산합니다.
class FaceAttentionSensor {
  FaceDetector? _detector;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  Timer? _timer;
  bool _running = false;
  bool _busy = false;

  FaceAttentionSensor();

  Future<void> start({
    CameraDescription? camera,
    required bool Function() appInForeground,
    bool skipCameraEnumeration = false,
  }) async {
    if (_running) return;
    _running = true;
    _signals = StreamController<AttentionSignals>.broadcast();

    if (skipCameraEnumeration && camera == null) {
      debugPrint('[FaceAttentionSensor-Web] 웹 로컬 미리보기 전용 → 집중 신호 스텁');
      _startStub(appInForeground);
      return;
    }

    // 웹: 상위에서 null 로 넘어와도 여기서 다시 enumerate (권한 직후 목록이 생김)
    CameraDescription? cam = camera;
    if (cam == null) {
      try {
        final cams = await availableCameras();
        if (cams.isEmpty) {
          debugPrint('[FaceAttentionSensor-Web] 카메라 없음 → 스텁');
          _startStub(appInForeground);
          return;
        }
        final front = cams
            .where((c) => c.lensDirection == CameraLensDirection.front)
            .toList();
        cam = front.isNotEmpty ? front.first : cams.first;
      } catch (e) {
        debugPrint('[FaceAttentionSensor-Web] availableCameras 실패: $e');
        _startStub(appInForeground);
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

      // 500ms 간격으로 사진 촬영 → detectFaces 호출
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
        if (!_running || _busy) return;
        _busy = true;
        try {
          final xfile = await _controller!.takePicture();
          final bytes = await xfile.readAsBytes();
          final faces = await _detector!.detectFaces(
            bytes,
            mode: FaceDetectionMode.full, // mesh + 홍채 포함
          );
          _signals?.add(attentionSignalsFromFaces(faces, appInForeground()));
        } catch (e) {
          debugPrint('[FaceAttentionSensor-Web] 감지 오류: $e');
          _signals?.add(AttentionSignals(
            facePresent: false,
            multiFace: false,
            appInForeground: appInForeground(),
          ));
        } finally {
          _busy = false;
        }
      });
    } catch (e) {
      // 카메라 초기화 실패 → 타이머 스텁으로 대체
      debugPrint('[FaceAttentionSensor-Web] 카메라 초기화 실패, 스텁 사용: $e');
      await _detector?.dispose();
      _detector = null;
      _startStub(appInForeground);
    }
  }

  void _startStub(bool Function() appInForeground) {
    void emit() {
      _signals?.add(AttentionSignals(
        facePresent: true,
        multiFace: false,
        appInForeground: appInForeground(),
      ));
    }

    emit();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => emit());
  }

  Stream<AttentionSignals> get stream =>
      _signals?.stream ?? const Stream.empty();

  CameraController? get controller => _controller;

  Future<void> stop() async {
    _running = false;
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
