// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert' show base64Decode;

import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/material.dart';

import '../domain/attention_signals.dart';
import 'web_attention_face_codec.dart';
import 'web_face_detector_holder.dart';

/// 브라우저 [getUserMedia]로 내 화면을 보여 주고, 같은 [VideoElement] 프레임을
/// 주기적으로 JPEG로 떠서 [FaceDetector]로 분석 → [onAttentionSignals] 로 실시간 전달합니다.
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
  static const String _sharedViewType = 'session-self-cam';
  static bool _sharedRegistered = false;
  static html.VideoElement? _sharedVideo;
  static html.MediaStream? _sharedStream;
  static int _sharedRefCount = 0;
  static Timer? _sharedDisposeTimer;

  html.VideoElement? _video;
  /// 카메라 자체 실패(권한·미지원)만 전체 화면 오류.
  String? _cameraError;
  /// 분석기 준비 중·재시도 — 카메라는 계속 보여 줌.
  String? _analysisStatus;

  FaceDetector? _detector;
  Timer? _analysisTimer;
  Timer? _detectorRetryTimer;
  bool _busy = false;
  bool _detectorInitInFlight = false;
  final WebAttentionFacePipeline _pipeline = WebAttentionFacePipeline();

  @override
  void initState() {
    super.initState();
    _sharedRefCount += 1;
    _sharedDisposeTimer?.cancel();
    _sharedDisposeTimer = null;

    _sharedVideo ??= html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.display = 'block'
      ..style.objectFit = 'cover'
      ..style.transform = 'scaleX(-1)';
    _video = _sharedVideo;

    if (!_sharedRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(
        _sharedViewType,
        (int _) => _sharedVideo!,
      );
      _sharedRegistered = true;
    }

    _applySize();
    unawaited(_boot());
  }

  @override
  void didUpdateWidget(SessionSelfCameraSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width || oldWidget.height != widget.height) {
      _applySize();
    }
  }

  void _applySize() {
    final v = _video;
    if (v == null) return;
    v.style.width = '${widget.width}px';
    v.style.height = '${widget.height}px';
  }

  static Future<html.MediaStream?> _ensureSharedStream() async {
    if (_sharedStream != null) return _sharedStream;
    final md = html.window.navigator.mediaDevices;
    if (md == null) return null;
    final stream = await md.getUserMedia({'video': true});
    _sharedStream = stream;
    _sharedVideo?.srcObject = stream;
    try {
      await _sharedVideo?.play();
    } catch (_) {}
    return _sharedStream;
  }

  Future<void> _boot() async {
    try {
      final md = html.window.navigator.mediaDevices;
      if (md == null) {
        if (mounted) {
          setState(() => _cameraError = '이 브라우저는 카메라를 지원하지 않아요.');
        }
        _emitNoFace();
        return;
      }
      final stream = await _ensureSharedStream();
      if (stream == null) {
        if (mounted) {
          setState(() => _cameraError =
              '카메라를 열 수 없어요. 주소창에서 카메라를 허용했는지 확인해 주세요.');
        }
        _emitNoFace();
        return;
      }

      if (mounted) {
        setState(() {
          _cameraError = null;
          _analysisStatus = '얼굴 분석 준비 중…';
        });
      }

      // 비디오 프레임이 준비된 뒤 WASM 초기화 (Safari에서 성공률↑)
      await _waitForVideoReady();
      await _ensureDetector();

      _analysisTimer?.cancel();
      _analysisTimer = Timer.periodic(
        const Duration(milliseconds: 900),
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

  Future<void> _waitForVideoReady() async {
    final v = _video;
    if (v == null) return;
    for (var i = 0; i < 40; i++) {
      if (v.readyState >= html.MediaElement.HAVE_CURRENT_DATA &&
          v.videoWidth >= 8 &&
          v.videoHeight >= 8) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _ensureDetector() async {
    if (_detector != null && _detector!.isReady) return;
    if (_detectorInitInFlight) return;
    _detectorInitInFlight = true;
    try {
      final d = await WebFaceDetectorHolder.instance.acquire();
      if (!mounted) return;
      if (d != null) {
        _detector = d;
        setState(() => _analysisStatus = null);
        _detectorRetryTimer?.cancel();
        _detectorRetryTimer = null;
      } else {
        setState(() => _analysisStatus = '얼굴 분석 준비 중… (자동 재시도)');
        _scheduleDetectorRetry();
      }
    } finally {
      _detectorInitInFlight = false;
    }
  }

  void _scheduleDetectorRetry() {
    _detectorRetryTimer?.cancel();
    _detectorRetryTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      WebFaceDetectorHolder.instance.disposeAll();
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
    if (!mounted || _busy || _video == null) return;
    if (_video!.readyState < html.MediaElement.HAVE_CURRENT_DATA) return;

    if (_detector == null || !_detector!.isReady) {
      await _ensureDetector();
      if (_detector == null) {
        _emitNoFace();
        return;
      }
    }

    final w = _video!.videoWidth;
    final h = _video!.videoHeight;
    if (w < 8 || h < 8) return;

    _busy = true;
    try {
      const maxD = 480.0;
      late final double outW;
      late final double outH;
      if (w >= h) {
        outW = w > maxD ? maxD : w.toDouble();
        outH = h * (outW / w);
      } else {
        outH = h > maxD ? maxD : h.toDouble();
        outW = w * (outH / h);
      }

      final canvas =
          html.CanvasElement(width: outW.round(), height: outH.round());
      final ctx = canvas.context2D;
      ctx
        ..save()
        ..scale(outW / w, outH / h)
        ..drawImage(_video!, 0, 0)
        ..restore();

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.88);
      final comma = dataUrl.indexOf(',');
      if (comma < 0 || comma >= dataUrl.length - 1) {
        _emitNoFace();
        return;
      }
      final bytes = Uint8List.fromList(
        base64Decode(dataUrl.substring(comma + 1)),
      );

      if (!WebAttentionFacePipeline.jpegLooksLikePhoto(bytes)) {
        _emitNoFace();
        return;
      }

      final det = _detector!;
      final fast = await det.detectFaces(
        bytes,
        mode: FaceDetectionMode.fast,
      );
      final fastOk =
          fast.where(WebAttentionFacePipeline.passesFastGate).toList();
      if (fastOk.isEmpty) {
        _emitNoFace();
        return;
      }

      final full = await det.detectFaces(
        bytes,
        mode: FaceDetectionMode.full,
      );
      final trusted = WebAttentionFacePipeline.filterTrustworthy(
        full,
        requireFastOverlap: fastOk,
      );

      if (!mounted) return;
      widget.onAttentionSignals(
        _pipeline.processFaces(trusted, widget.appInForeground()),
      );
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
    _analysisTimer = null;
    _detectorRetryTimer?.cancel();
    _detectorRetryTimer = null;
    _pipeline.reset();
    WebFaceDetectorHolder.instance.release();
    _detector = null;

    _sharedRefCount = (_sharedRefCount - 1).clamp(0, 1 << 30);
    if (_sharedRefCount == 0) {
      _sharedDisposeTimer?.cancel();
      _sharedDisposeTimer = Timer(const Duration(seconds: 8), () {
        for (final t in _sharedStream?.getTracks() ?? <html.MediaStreamTrack>[]) {
          t.stop();
        }
        _sharedStream = null;
        try {
          _sharedVideo?.srcObject = null;
        } catch (_) {}
        unawaited(WebFaceDetectorHolder.instance.disposeAll());
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_video == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const HtmlElementView(viewType: _sharedViewType),
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
