import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';

import '../domain/attention_signals.dart';

/// 앱(iOS·Android·macOS·Windows·Linux)용 얼굴 집중도 센서.
///
/// face_detection_tflite 로 카메라 스트림을 처리하며,
/// EAR·머리 방향·깜빡임을 계산해 [AttentionSignals] 를 내보냅니다.
class FaceAttentionSensor {
  FaceDetector? _detector;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  bool _running = false;
  bool _busy = false;

  // ── MediaPipe 468-point mesh 인덱스 ──────────────────────────
  // EAR 계산에 쓰는 눈 윤곽 6점 (표준 MediaPipe Face Mesh 인덱스)
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

    // iOS·macOS는 bgra8888만 지원. Android는 yuv420 사용.
    final isBgraDevice = Platform.isIOS || Platform.isMacOS;
    _controller = CameraController(
      cam,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: isBgraDevice
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();

    await _controller!.startImageStream((image) async {
      if (!_running || _busy) return;
      _busy = true;
      try {
        final rotation = _rotationFor(cam);
        
        List<Face> faces = const [];
        
        if (isBgraDevice) {
          // iOS/macOS bgra8888 포맷의 경우 camera 플러그인이 bytesPerPixel을 null로 반환하는 버그가 있어,
          // face_detection_tflite 내부에서 pixelStride를 1로 잘못 인식해 프레임이 무시되는 문제를 우회합니다.
          final frame = prepareCameraFrame(
            width: image.width,
            height: image.height,
            planes: [
              for (final p in image.planes)
                (
                  bytes: p.bytes,
                  rowStride: p.bytesPerRow,
                  pixelStride: p.bytesPerPixel ?? 4, // bgra8888은 픽셀당 4바이트
                )
            ],
            rotation: rotation,
            isBgra: true,
          );
          
          if (frame != null) {
            faces = await _detector!.detectFacesFromCameraFrame(
              frame,
              mode: FaceDetectionMode.full,
              maxDim: 320,
            ).timeout(const Duration(milliseconds: 1000));
          }
        } else {
          faces = await _detector!.detectFacesFromCameraImage(
            image,
            rotation: rotation,
            isBgra: false,
            mode: FaceDetectionMode.full,
            maxDim: 320,
          ).timeout(const Duration(milliseconds: 1000));
        }
        
        _signals?.add(_toSignals(faces, appInForeground()));
      } catch (e) {
        debugPrint('FaceAttentionSensor: detectFacesFromCameraImage error: $e');
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

  // ── 신호 변환 ────────────────────────────────────────────────

  AttentionSignals _toSignals(List<Face> faces, bool inForeground) {
    if (faces.isEmpty) {
      return AttentionSignals(
        facePresent: false,
        multiFace: false,
        appInForeground: inForeground,
      );
    }

    final face = faces.first;
    final mesh = face.mesh; // FaceMesh? (468점)

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

  // ── EAR (Eye Aspect Ratio) ───────────────────────────────────
  // EAR = (|p2-p6| + |p3-p5|) / (2 * |p1-p4|)
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

  // ── 간이 머리 방향 추정 ──────────────────────────────────────
  // 코끝(1번)을 기준으로 왼쪽 눈꼬리(226)·오른쪽 눈꼬리(446)의 상대 위치로
  // yaw(좌우)·pitch(상하)를 도 단위로 추정합니다.
  (double yaw, double pitch) _estimateHeadPose(FaceMesh mesh) {
    try {
      final nose = mesh[1];
      final eyeL = mesh[226];
      final eyeR = mesh[446];
      final chin = mesh[152];

      // 눈 중심
      final eyeCx = (eyeL.x + eyeR.x) / 2;
      final eyeCy = (eyeL.y + eyeR.y) / 2;

      // 눈 간격
      final eyeWidth = (eyeR.x - eyeL.x).abs();
      if (eyeWidth < 1e-6) return (0.0, 0.0);

      // yaw: 코끝이 눈 중심 대비 얼마나 좌우로 치우쳤나
      final yawRatio = (nose.x - eyeCx) / eyeWidth;
      final yaw = yawRatio * 90.0;

      // pitch: 코끝이 눈-턱 중간 대비 얼마나 위/아래로 치우쳤나
      final faceHeight = (chin.y - eyeCy).abs().clamp(1.0, double.infinity);
      final pitchRatio = (nose.y - eyeCy) / faceHeight;
      final pitch = (pitchRatio - 0.35) * 120.0; // 0.35: 정면 기준 오프셋

      return (yaw, pitch);
    } catch (_) {
      return (0.0, 0.0);
    }
  }

  // ── 카메라 회전 ──────────────────────────────────────────────
  // CameraFrameRotation은 cw90/cw180/cw270만 있고 0도는 null로 전달합니다.
  CameraFrameRotation? _rotationFor(CameraDescription cam) {
    if (kIsWeb) return null;
    // iOS와 macOS의 camera 플러그인은 이미지를 pre-rotate 해서 제공하므로 회전이 필요 없습니다.
    if (Platform.isIOS || Platform.isMacOS) return null;
    
    return switch (cam.sensorOrientation) {
      90 => CameraFrameRotation.cw90,
      180 => CameraFrameRotation.cw180,
      270 => CameraFrameRotation.cw270,
      _ => null, // 0도 및 기타 → 회전 없음
    };
  }
}
