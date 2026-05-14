import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';

import '../domain/attention_signals.dart';

/// 앱(iOS·Android·macOS·Windows·Linux)용 얼굴 집중도 센서.
///
/// 플랫폼별 처리 방식:
///   - iOS · Android : startImageStream (yuv420) → 가장 빠르고 안정적인 실시간 분석
///   - macOS         : startImageStream (bgra8888) → macOS는 yuv420 미지원
class FaceAttentionSensor {
  FaceDetector? _detector;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  bool _running = false;
  bool _busy = false;

  // ── MediaPipe 468-point mesh 인덱스 ──────────────────────────
  static const _eyeL = [362, 385, 387, 263, 373, 380];
  static const _eyeR = [33, 160, 158, 133, 153, 144];

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
      ResolutionPreset.low,
      enableAudio: false,
      // iOS와 Android 모두 yuv420 포맷을 완벽하게 지원합니다.
      // macOS만 bgra8888을 사용합니다.
      imageFormatGroup: isMacOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();

    await _controller!.startImageStream((image) async {
      if (!_running || _busy) return;
      _busy = true;
      try {
        final rotation = _rotationFor(cam);
        List<Face> faces;

        if (isMacOS) {
          // macOS bgra8888
          final frame = prepareCameraFrame(
            width: image.width,
            height: image.height,
            planes: [
              for (final p in image.planes)
                (
                  bytes: p.bytes,
                  rowStride: p.bytesPerRow,
                  pixelStride: p.bytesPerPixel ?? 4,
                )
            ],
            rotation: rotation,
            isBgra: true,
          );
          faces = frame == null
              ? const []
              : await _detector!
                  .detectFacesFromCameraFrame(
                    frame,
                    mode: FaceDetectionMode.full,
                    maxDim: 320,
                  )
                  .timeout(const Duration(milliseconds: 1500));
        } else {
          // iOS, Android는 yuv420 (NV12/NV21)
          // takePicture() 방식은 iOS에서 프레임이 캐싱(동결)되는 버그가 있어
          // 실시간 분석에 적합한 startImageStream + yuv420 조합으로 복구합니다.
          faces = await _detector!
              .detectFacesFromCameraImage(
                image,
                rotation: rotation,
                isBgra: false,
                mode: FaceDetectionMode.full,
                maxDim: 320,
              )
              .timeout(const Duration(milliseconds: 1500));
        }

        _signals?.add(_toSignals(faces, appInForeground()));
      } catch (e) {
        debugPrint('FaceAttentionSensor: 감지 오류 → $e');
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

  Stream<AttentionSignals> get stream =>
      _signals?.stream ?? const Stream.empty();

  CameraController? get controller => _controller;

  Future<void> stop() async {
    _running = false;
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

    double earL = 0.3, earR = 0.3;
    double yaw = 0, pitch = 0;
    bool blink = false;

    if (mesh != null && mesh.length >= 468) {
      earL = _ear(mesh, _eyeL);
      earR = _ear(mesh, _eyeR);
      blink = earL < 0.2 && earR < 0.2;

      final pose = _estimateHeadPose(mesh);
      yaw = pose.$1;
      pitch = pose.$2;
    }

    return AttentionSignals(
      facePresent: true,
      multiFace: faces.length > 1,
      appInForeground: inForeground,
      earLeft: earL,
      earRight: earR,
      headYaw: yaw,
      headPitch: pitch,
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
    if (h < 1e-6) return 0.3;
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

  CameraFrameRotation? _rotationFor(CameraDescription cam) {
    if (kIsWeb) return null;
    // iOS와 macOS의 camera 플러그인은 이미지를 upright(정방향)으로 pre-rotate 해서 제공하므로 회전이 필요 없습니다.
    // 안드로이드만 센서 방향에 따른 회전이 필요합니다.
    if (Platform.isIOS || Platform.isMacOS) return null;
    
    return switch (cam.sensorOrientation) {
      90 => CameraFrameRotation.cw90,
      180 => CameraFrameRotation.cw180,
      270 => CameraFrameRotation.cw270,
      _ => null,
    };
  }
}
