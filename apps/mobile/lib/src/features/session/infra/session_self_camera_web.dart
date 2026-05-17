// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'dart:ui_web' as ui_web;

import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/material.dart';

import '../domain/attention_signals.dart';
import 'web_attention_face_codec.dart';
import 'web_face_detector_holder.dart';
import 'web_shared_camera.dart';

/// 브라우저 공유 카메라 + [FaceDetector] 분석 → [onAttentionSignals].
///
/// [detectFacesFromVideo] 대신 JPEG 캡처 → [FaceDetector.detectFaces] 경로를
/// 사용합니다. dart:html ↔ package:web 타입 불일치를 피하고 Safari 호환성을 높입니다.
class SessionSelfCameraSurface extends StatefulWidget {
  final double width;
  final double height;
  final bool Function() appInForeground;
  final void Function(AttentionSignals) onAttentionSignals;

  const SessionSelfCameraSurface({
    super.key,
    required this.width,
    required this.height,
    required this.appInForeground,
    required this.onAttentionSignals,
  });

  @override
  State<SessionSelfCameraSurface> createState() => _SessionSelfCameraSurfaceState();
}

class _SessionSelfCameraSurfaceState extends State<SessionSelfCameraSurface> {
  static int _viewTypeSeq = 0;

  late final String _viewType = 'session-self-cam-${_viewTypeSeq++}';
  late final html.DivElement _host = html.DivElement()
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.overflow = 'hidden'
    ..style.backgroundColor = '#000';

  bool _viewRegistered = false;
  String? _cameraError;
  String? _analysisStatus;
  bool _streamReady = false;

  Timer? _analysisTimer;
  Timer? _detectorRetryTimer;
  bool _busy = false;
  int _retryCount = 0;
  final WebAttentionFacePipeline _pipeline = WebAttentionFacePipeline();

  @override
  void initState() {
    super.initState();
    _registerHost();
    unawaited(_boot());
  }

  void _registerHost() {
    if (_viewRegistered) return;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _host,
    );
    _viewRegistered = true;
  }

  @override
  void didUpdateWidget(SessionSelfCameraSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applySize();
  }

  void _applySize() {
    _host.style.width = '${widget.width}px';
    _host.style.height = '${widget.height}px';
    final v = WebSharedCamera.instance.video;
    if (v == null) return;
    v.style.width = '100%';
    v.style.height = '100%';
  }

  void _attachVideo() {
    final video = WebSharedCamera.instance.video;
    if (video == null) return;
    if (_host.contains(video)) return;
    _host.nodes.clear();
    _host.nodes.add(video);
  }

  Future<void> _boot() async {
    try {
      final stream = await WebSharedCamera.instance.acquire();
      if (stream == null) {
        final err = WebSharedCamera.instance.lastOpenError;
        if (mounted) {
          setState(() {
            _cameraError = err != null
                ? 'Safari 설정에서 카메라를 허용해 주세요. (${err.split('(').first.trim()})'
                : '이 브라우저는 카메라를 지원하지 않아요.';
          });
        }
        _emitNoFace();
        return;
      }

      _attachVideo();
      _applySize();

      if (mounted) {
        setState(() {
          _cameraError = null;
          _streamReady = true;
          _analysisStatus = '얼굴 분석 준비 중…';
        });
      }

      unawaited(_ensureDetector());

      _analysisTimer?.cancel();
      _analysisTimer = Timer.periodic(
        const Duration(milliseconds: 800),
        (_) => unawaited(_sampleFrame()),
      );
      unawaited(_sampleFrame());
    } catch (e) {
      debugPrint('[SessionSelfCamera-Web] boot: $e');
      if (mounted) {
        setState(() => _cameraError =
            '카메라를 열 수 없어요. 주소창에서 카메라를 허용했는지 확인해 주세요.');
      }
      _emitNoFace();
    }
  }

  Future<void> _ensureDetector() async {
    if (WebFaceDetectorHolder.instance.isReady) {
      _onDetectorReady();
      return;
    }
    final d = await WebFaceDetectorHolder.instance.acquire();
    if (!mounted) return;
    if (d != null) {
      _onDetectorReady();
    } else {
      _scheduleDetectorRetry();
    }
  }

  void _onDetectorReady() {
    _retryCount = 0;
    _detectorRetryTimer?.cancel();
    if (mounted) {
      setState(() => _analysisStatus = null);
    }
  }

  void _scheduleDetectorRetry() {
    if (_retryCount >= 6) {
      if (mounted) {
        setState(() => _analysisStatus =
            '분석 엔진 로딩이 느립니다. Wi‑Fi 확인 후 새로고침해 주세요.');
      }
      return;
    }
    _retryCount++;
    _detectorRetryTimer?.cancel();
    _detectorRetryTimer = Timer(Duration(seconds: 3 + _retryCount * 2), () {
      if (!mounted) return;
      WebFaceDetectorHolder.instance.scheduleRetry();
      unawaited(_ensureDetector());
    });
  }

  void _emitNoFace() {
    if (!mounted) return;
    widget.onAttentionSignals(
      _pipeline.noFace(widget.appInForeground()),
    );
  }

  Future<void> _sampleFrame() async {
    if (!mounted || _busy) return;
    if (!WebSharedCamera.instance.isStreamReady) {
      _attachVideo();
      return;
    }

    final det = WebFaceDetectorHolder.instance.detector;
    if (det == null) {
      unawaited(_ensureDetector());
      _emitNoFace();
      return;
    }

    _busy = true;
    try {
      final jpeg = await WebSharedCamera.instance.captureJpeg(
        maxDim: 480,
        quality: 0.82,
      );

      if (jpeg == null || !WebAttentionFacePipeline.jpegLooksLikePhoto(jpeg)) {
        _emitNoFace();
        return;
      }

      List<Face> fast = const [];
      List<Face> full = const [];

      try {
        fast = await det.detectFaces(jpeg, mode: FaceDetectionMode.fast);
      } catch (e) {
        debugPrint('[SessionSelfCamera-Web] fast: $e');
      }

      if (fast.isNotEmpty) {
        try {
          full = await det.detectFaces(jpeg, mode: FaceDetectionMode.full);
        } catch (e) {
          debugPrint('[SessionSelfCamera-Web] full: $e');
        }
      }

      if (!mounted) return;

      final sig = _pipeline.processDetection(
        fullFaces: full,
        fastFaces: fast,
        inForeground: widget.appInForeground(),
      );

      if (mounted && _analysisStatus != null) {
        setState(() => _analysisStatus = null);
      }

      widget.onAttentionSignals(sig);
    } catch (e) {
      debugPrint('[SessionSelfCamera-Web] sample: $e');
      _emitNoFace();
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _detectorRetryTimer?.cancel();
    _pipeline.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _cameraError!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      );
    }

    if (!_streamReady) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          HtmlElementView(viewType: _viewType),
          if (_analysisStatus != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    _analysisStatus!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
