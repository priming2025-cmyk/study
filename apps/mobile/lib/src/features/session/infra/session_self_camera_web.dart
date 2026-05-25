// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'dart:ui_web' as ui_web;

import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/material.dart';

import '../domain/attention_signals.dart';
import 'web_attention_face_codec.dart';
import 'web_face_detector_holder.dart';
import 'web_mediapipe_face_detector.dart';
import 'web_shared_camera.dart';

/// 브라우저 공유 카메라 + [FaceDetector] 분석 → [onAttentionSignals].
class SessionSelfCameraSurface extends StatefulWidget {
  final double width;
  final double height;

  /// false면 카메라 스트림을 놓아 다른 탭(셋터디)과 충돌하지 않게 합니다.
  final bool active;
  final bool Function() appInForeground;
  final void Function(AttentionSignals) onAttentionSignals;

  const SessionSelfCameraSurface({
    super.key,
    required this.width,
    required this.height,
    this.active = true,
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
  bool _analysisFailed = false;
  bool _streamReady = false;
  bool _cameraRunning = false;

  Timer? _analysisTimer;
  Timer? _detectorRetryTimer;
  bool _busy = false;
  int _retryCount = 0;
  final WebAttentionFacePipeline _pipeline = WebAttentionFacePipeline();

  bool get _isMobileSafari => WebFaceDetectorHolder.isMobileSafari;

  /// iPhone은 MediaPipe가 주 경로 → LiteRT 재시도는 최소화.
  int get _maxDetectorRetries => _isMobileSafari ? 3 : 8;

  String get _preparingMsg => '얼굴 분석 준비 중…';

  @override
  void initState() {
    super.initState();
    _registerHost();
    if (widget.active) {
      unawaited(_boot());
    }
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
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        unawaited(_boot());
      } else {
        unawaited(_shutdown());
      }
    }
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
    if (_host.contains(video)) {
      unawaited(video.play());
      return;
    }
    _host.nodes.clear();
    _host.nodes.add(video);
    unawaited(video.play());
  }

  Future<void> _shutdown() async {
    if (!_cameraRunning) {
      _analysisTimer?.cancel();
      _analysisTimer = null;
      return;
    }
    _analysisTimer?.cancel();
    _analysisTimer = null;
    _detectorRetryTimer?.cancel();
    _detectorRetryTimer = null;
    _busy = false;
    _retryCount = 0;
    _pipeline.reset();
    WebSharedCamera.instance.release();
    _cameraRunning = false;
    if (mounted) {
      setState(() {
        _streamReady = false;
        _cameraError = null;
        _analysisStatus = null;
        _analysisFailed = false;
      });
    }
    _emitNoFace();
  }

  Future<void> _boot() async {
    if (!widget.active || _cameraRunning) return;
    _cameraRunning = true;
    try {
      final stream = await WebSharedCamera.instance.acquire();
      if (stream == null) {
        _cameraRunning = false;
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
          _analysisFailed = false;
          _analysisStatus = _preparingMsg;
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
      _cameraRunning = false;
      if (mounted) {
        setState(() => _cameraError =
            '카메라를 열 수 없어요. 주소창에서 카메라를 허용했는지 확인해 주세요.');
      }
      _emitNoFace();
    }
  }

  Future<void> _ensureDetector() async {
    // ── iPhone: MediaPipe 우선 (WebGL, 10~15 초 준비) ────────────────────
    if (_isMobileSafari) {
      if (WebMediaPipeFaceDetector.isReady) {
        _onDetectorReady();
        return;
      }
      // MediaPipe가 아직 로딩 중이면 최대 25 초 대기
      await WebMediaPipeFaceDetector.waitUntilReady(
        timeout: const Duration(seconds: 25),
      );
      if (!mounted) return;
      if (WebMediaPipeFaceDetector.isReady) {
        _onDetectorReady();
        return;
      }
      // MediaPipe 실패 → LiteRT 폴백
    }

    // ── 데스크탑 / Android Chrome 또는 MediaPipe 실패 시 LiteRT ───────────
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
      setState(() {
        _analysisStatus = null;
        _analysisFailed = false;
      });
    }
  }

  Future<void> _retryDetectorNow() async {
    _retryCount = 0;
    _analysisFailed = false;
    if (mounted) setState(() => _analysisStatus = _preparingMsg);
    // MediaPipe 재시도 (iPhone)
    if (_isMobileSafari) {
      await _ensureDetector();
      return;
    }
    // LiteRT 재시도
    WebFaceDetectorHolder.instance.scheduleRetry();
    unawaited(WebFaceDetectorHolder.instance.warmUp());
    await _ensureDetector();
  }

  void _scheduleDetectorRetry() {
    if (_retryCount >= _maxDetectorRetries) {
      if (mounted) {
        setState(() {
          _analysisFailed = true;
          _analysisStatus =
              '분석을 시작하지 못했어요. Wi‑Fi가 안정적인 곳에서 아래 버튼으로 다시 시도해 주세요.';
        });
      }
      return;
    }
    _retryCount++;
    final delaySec = _isMobileSafari
        ? (4 + _retryCount).clamp(4, 12)
        : (2 + _retryCount).clamp(2, 8);
    _detectorRetryTimer?.cancel();
    _detectorRetryTimer = Timer(Duration(seconds: delaySec), () {
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

    _busy = true;
    try {
      // ── iPhone: MediaPipe 경로 (WebGL, 빠름) ──────────────────────────
      if (_isMobileSafari && WebMediaPipeFaceDetector.isReady) {
        final video = WebSharedCamera.instance.video;
        if (video != null) {
          final sig = WebMediaPipeFaceDetector.detectFromVideo(
            video,
            widget.appInForeground(),
          );
          // null → 비디오 미준비 등 일시 오류: noFace만 내보내고 LiteRT 경로로 넘기지 않음
          _clearStatus();
          widget.onAttentionSignals(sig ?? _pipeline.noFace(widget.appInForeground()));
          return;
        }
      }

      // ── LiteRT 경로 (데스크탑·Android 또는 MediaPipe 초기화 전) ──────
      final det = WebFaceDetectorHolder.instance.detector;
      if (det == null) {
        unawaited(_ensureDetector());
        _emitNoFace();
        return;
      }

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

      _clearStatus();
      widget.onAttentionSignals(sig);
    } catch (e) {
      debugPrint('[SessionSelfCamera-Web] sample: $e');
      _emitNoFace();
    } finally {
      _busy = false;
    }
  }

  void _clearStatus() {
    if (mounted && (_analysisStatus != null || _analysisFailed)) {
      setState(() {
        _analysisStatus = null;
        _analysisFailed = false;
      });
    }
  }

  @override
  void dispose() {
    unawaited(_shutdown());
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
          if (_analysisStatus != null || _analysisFailed)
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
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _analysisStatus ?? '',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                      if (_analysisFailed) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => unawaited(_retryDetectorNow()),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                          ),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
