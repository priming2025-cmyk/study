import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../domain/attention_signals.dart';

class FaceAttentionSensor {
  final FaceDetector _detector;
  CameraController? _controller;
  StreamController<AttentionSignals>? _signals;
  bool _running = false;

  FaceAttentionSensor()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            enableClassification: false,
            enableContours: false,
            enableLandmarks: false,
            performanceMode: FaceDetectorMode.fast,
          ),
        );

  Future<void> start({
    CameraDescription? camera,
    required bool Function() appInForeground,
  }) async {
    if (_running) return;
    final cam = camera;
    if (cam == null) {
      throw StateError('카메라가 필요합니다.');
    }
    _running = true;
    _signals = StreamController<AttentionSignals>.broadcast();

    _controller = CameraController(
      cam,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();

    await _controller!.startImageStream((image) async {
      if (!_running) return;
      if (_busy) return;
      _busy = true;
      try {
        final input = _toInputImage(image, cam);
        final faces = await _detector.processImage(input);
        final facePresent = faces.isNotEmpty;
        final multiFace = faces.length > 1;
        _signals?.add(
          AttentionSignals(
            facePresent: facePresent,
            multiFace: multiFace,
            appInForeground: appInForeground(),
          ),
        );
      } catch (_) {
        _signals?.add(
          AttentionSignals(
            facePresent: false,
            multiFace: false,
            appInForeground: appInForeground(),
          ),
        );
      } finally {
        _busy = false;
      }
    });
  }

  bool _busy = false;

  Stream<AttentionSignals> get stream {
    final s = _signals;
    if (s == null) {
      return const Stream.empty();
    }
    return s.stream;
  }

  CameraController? get controller => _controller;

  Future<void> stop() async {
    _running = false;
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    await _controller?.dispose();
    _controller = null;

    await _detector.close();
    await _signals?.close();
    _signals = null;
  }

  InputImage _toInputImage(CameraImage image, CameraDescription camera) {
    final bytes = _concatenatePlanes(image.planes);
    final rotation = _rotationFromSensor(camera.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final buffer = WriteBuffer();
    for (final plane in planes) {
      buffer.putUint8List(plane.bytes);
    }
    return buffer.done().buffer.asUint8List();
  }

  InputImageRotation _rotationFromSensor(int sensorOrientation) {
    return switch (sensorOrientation) {
      0 => InputImageRotation.rotation0deg,
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      270 => InputImageRotation.rotation270deg,
      _ => InputImageRotation.rotation0deg,
    };
  }
}
