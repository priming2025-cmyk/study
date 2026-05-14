import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';

import '../domain/attention_signals.dart';
import 'web_attention_face_codec.dart';

/// 앱(iOS·Android·macOS·Windows·Linux)용 얼굴 집중도 센서.
///
/// 플랫폼별 처리 방식:
///   - iOS · macOS : takePicture() → JPEG bytes → detectFaces(bytes)
///                  (raw 픽셀 포맷(bgra8888/yuv420) 이슈를 완전히 우회)
///   - Android     : startImageStream → detectFacesFromCameraImage (yuv420)
class FaceAttentionSensor {
  FaceDetector? _detector;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  Timer? _snapshotTimer; // iOS·macOS 전용
  bool _running = false;
  bool _busy = false;

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

    // _signals를 먼저 생성해야 start() 반환 직후 stream.listen()이 올바른 스트림을 구독합니다.
    _signals = StreamController<AttentionSignals>.broadcast();

    _detector = FaceDetector();
    await _detector!.initialize(
      model: cam.lensDirection == CameraLensDirection.front
          ? FaceDetectionModel.frontCamera
          : FaceDetectionModel.backCamera,
    );

    _controller = CameraController(
      cam,
      ResolutionPreset.low,
      enableAudio: false,
      // iOS·macOS는 takePicture() 방식이므로 imageFormatGroup 불필요.
      // Android만 startImageStream에서 yuv420 사용.
      imageFormatGroup: (Platform.isIOS || Platform.isMacOS)
          ? null
          : ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();

    if (Platform.isIOS || Platform.isMacOS) {
      // ── iOS·macOS: 500ms 간격으로 JPEG 캡처 후 detectFaces(bytes) ──────
      // startImageStream의 raw 픽셀 포맷(bgra8888/NV12) 관련 이슈를 완전히 우회합니다.
      // 웹 버전(SessionSelfCameraSurface)과 동일한 detectFaces(bytes) 코드 경로 사용.
      _snapshotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
        if (!_running || _busy) return;
        _busy = true;
        try {
          final xfile = await _controller!.takePicture();
          final bytes = await xfile.readAsBytes();
          final faces = await _detector!
              .detectFaces(bytes, mode: FaceDetectionMode.full)
              .timeout(const Duration(milliseconds: 2000));
          _signals?.add(attentionSignalsFromFaces(faces, appInForeground()));
        } catch (e) {
          debugPrint('FaceAttentionSensor(iOS): 감지 오류 → $e');
          _signals?.add(AttentionSignals(
            facePresent: false,
            multiFace: false,
            appInForeground: appInForeground(),
          ));
        } finally {
          _busy = false;
        }
      });
    } else {
      // ── Android: startImageStream + detectFacesFromCameraImage (yuv420) ──
      final rotation = _rotationFor(cam);
      await _controller!.startImageStream((image) async {
        if (!_running || _busy) return;
        _busy = true;
        try {
          final faces = await _detector!
              .detectFacesFromCameraImage(
                image,
                rotation: rotation,
                isBgra: false,
                mode: FaceDetectionMode.full,
                maxDim: 320,
              )
              .timeout(const Duration(milliseconds: 1500));
          _signals?.add(attentionSignalsFromFaces(faces, appInForeground()));
        } catch (e) {
          debugPrint('FaceAttentionSensor(Android): 감지 오류 → $e');
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
  }

  Stream<AttentionSignals> get stream =>
      _signals?.stream ?? const Stream.empty();

  CameraController? get controller => _controller;

  Future<void> stop() async {
    _running = false;
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    await _controller?.dispose();
    _controller = null;
    await _detector?.dispose();
    _detector = null;
    await _signals?.close();
    _signals = null;
  }

  // ── 카메라 회전 (Android 전용) ───────────────────────────────────────────
  CameraFrameRotation? _rotationFor(CameraDescription cam) {
    if (kIsWeb) return null;
    return switch (cam.sensorOrientation) {
      90 => CameraFrameRotation.cw90,
      180 => CameraFrameRotation.cw180,
      270 => CameraFrameRotation.cw270,
      _ => null,
    };
  }
}
