// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'dart:ui_web' as ui_web;

import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/material.dart';

import '../domain/attention_signals.dart';
import 'web_attention_face_codec.dart';
import 'web_shared_camera.dart';
import 'web_face_detector_holder.dart';

/// 브라우저 공유 카메라 + [FaceDetector] 분석 → [onAttentionSignals].
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
    _registerViewHost();
    unawaited(_boot());
  }

  void _registerViewHost() {
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
    _attachVideoIfNeeded();
  }

  void _applySize() {
    _host.style.width = '${widget.width}px';
    _host.style.height = '${widget.height}px';
    final v = WebSharedCamera.instance.video;
    if (v != null) {
      v.style.width = '${widget.width}px';
      v.style.height = '${widget.height}px';
    }
  }

  void _attachVideoIfNeeded() {
    final video = WebSharedCamera.instance.video;
    if (video == null) return;
    if (_host.children.contains(video)) return;
    _host.children.clear();
    _host.append(video);
  }

  Future<void> _boot() async {
    try {
      final stream = await WebSharedCamera.instance.acquire();
      if (stream == null) {
        final err = WebSharedCamera.instance.lastOpenError;
        if (mounted) {
          setState(() {
            _cameraError = err != null
                ? '카메라를 열 수 없어요. Safari 설정에서 카메라를 허용해 주세요.'
                : '이 브라우저는 카메라를 지원하지 않아요.';
          });
        }
        _emitNoFace();
        return;
      }

      _attachVideoIfNeeded();
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
        const Duration(milliseconds: 650),
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
    if (_retryCount >= 8) {
      if (mounted) {
        setState(() => _analysisStatus =
            '분석 엔진 로딩이 느립니다. Wi‑Fi 확인 후 새로고침해 주세요.');
      }
      return;
    }
    _retryCount++;
    _detectorRetryTimer?.cancel();
    _detectorRetryTimer = Timer(Duration(seconds: 2 + _retryCount), () {
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

  Future<List<Face>> _detectFast(FaceDetector det, Object video) async {
    try {
      return await det.detectFacesFromVideo(
        video,
        mode: FaceDetectionMode.fast,
      );
    } catch (e) {
      debugPrint('[SessionSelfCamera-Web] fast video: $e');
      return const [];
    }
  }

  Future<List<Face>> _detectFastFromBytes(FaceDetector det, Uint8List jpeg) async {
    try {
      return await det.detectFaces(jpeg, mode: FaceDetectionMode.fast);
    } catch (e) {
      debugPrint('[SessionSelfCamera-Web] fast jpeg: $e');
      return const [];
    }
  }

  Future<void> _sampleFrame() async {
    if (!mounted || _busy) return;

    if (!WebSharedCamera.instance.isStreamReady) {
      return;
    }

    _attachVideoIfNeeded();

    final video = WebSharedCamera.instance.video;
    if (video == null) return;

    var det = WebFaceDetectorHolder.instance.detector;
    if (det == null) {
      unawaited(_ensureDetector());
      _emitNoFace();
      return;
    }

    _busy = true;
    try {
      var fast = await _detectFast(det, video);
      var full = const <Face>[];

      if (fast.isNotEmpty) {
        try {
          full = await det.detectFacesFromVideo(
            video,
            mode: FaceDetectionMode.full,
          );
        } catch (e) {
          debugPrint('[SessionSelfCamera-Web] full video: $e');
        }
      }

      if (fast.isEmpty) {
        final jpeg = await WebSharedCamera.instance.captureJpeg(
          maxDim: 480,
          quality: 0.82,
        );
        if (jpeg != null && WebAttentionFacePipeline.jpegLooksLikePhoto(jpeg)) {
          fast = await _detectFastFromBytes(det, jpeg);
          if (fast.isNotEmpty) {
            try {
              full = await det.detectFaces(jpeg, mode: FaceDetectionMode.full);
            } catch (e) {
              debugPrint('[SessionSelfCamera-Web] full jpeg: $e');
            }
          }
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
    // 탭 전환 시 release 하지 않음 — Safari는 재허용 제스처가 필요합니다.
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

    if (!_streamReady && !WebSharedCamera.instance.isStreamReady) {
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
