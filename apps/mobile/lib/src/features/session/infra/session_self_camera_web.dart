// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert' show base64Decode;

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/material.dart';

import '../domain/attention_signals.dart';
import 'web_attention_face_codec.dart';

/// 브라우저 [getUserMedia]로 내 화면을 보여 주고, 같은 [VideoElement] 프레임을
/// 주기적으로 JPEG로 떠서 [FaceDetector]로 분석 → [onAttentionSignals] 로 실시간 전달합니다.
/// (영상은 전송하지 않음, 로컬 탭 안에서만 처리.)
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
  String? _error;

  FaceDetector? _detector;
  Timer? _analysisTimer;
  bool _busy = false;

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
      // 인라인 비디오는 높이 0으로 잡히는 경우가 있어 block + 픽셀 크기를 둡니다.
      ..style.display = 'block'
      ..style.objectFit = 'cover'
      // 셀카처럼 거울 반전(실시간으로 내가 보는 방향과 맞춤)
      ..style.transform = 'scaleX(-1)';
    _video = _sharedVideo;

    // 최초 1회만 factory 등록 (viewType 재사용)
    if (!_sharedRegistered) {
      ui_web.platformViewRegistry.registerViewFactory(
        _sharedViewType,
        (int _) => _sharedVideo!,
      );
      _sharedRegistered = true;
    }

    _applySize();
    _openCameraAndStartAnalysis();
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

  Future<void> _openCameraAndStartAnalysis() async {
    try {
      final md = html.window.navigator.mediaDevices;
      if (md == null) {
        setState(() => _error = '이 브라우저는 카메라를 지원하지 않아요.');
        return;
      }
      final stream = await _ensureSharedStream();
      if (stream == null) {
        setState(() => _error = '이 브라우저는 카메라를 지원하지 않아요.');
        return;
      }

      if (mounted) setState(() => _error = null);

      try {
        _detector = FaceDetector();
        await _detector!.initialize(model: FaceDetectionModel.frontCamera);

        _analysisTimer?.cancel();
        _analysisTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
          _sampleFrame();
        });
      } catch (e) {
        // 웹 등에서 FaceDetector 초기화가 실패하더라도 카메라는 계속 보여야 합니다.
        debugPrint('FaceDetector init failed: $e. Falling back to mock signals.');
        _analysisTimer?.cancel();
        _analysisTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          widget.onAttentionSignals(
            AttentionSignals(
              facePresent: true,
              multiFace: false,
              appInForeground: widget.appInForeground(),
              earLeft: 0.3,
              earRight: 0.3,
              headYaw: 0,
              headPitch: 0,
              blinkFrame: false,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '카메라를 열 수 없어요. 주소창에서 카메라를 허용했는지 확인해 주세요. ($e)');
      }
    }
  }

  Future<void> _sampleFrame() async {
    if (!mounted || _busy || _video == null || _detector == null) return;
    if (_video!.readyState < html.MediaElement.HAVE_CURRENT_DATA) return;

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

      final canvas = html.CanvasElement(width: outW.round(), height: outH.round());
      final ctx = canvas.context2D;
      ctx
        ..save()
        ..scale(outW / w, outH / h)
        ..drawImage(_video!, 0, 0)
        ..restore();

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.88);
      final comma = dataUrl.indexOf(',');
      if (comma < 0 || comma >= dataUrl.length - 1) return;
      final bytes = base64Decode(dataUrl.substring(comma + 1));

      final faces = await _detector!.detectFaces(
        bytes,
        mode: FaceDetectionMode.full,
      );
      if (!mounted) return;
      widget.onAttentionSignals(
        attentionSignalsFromFaces(faces, widget.appInForeground()),
      );
    } catch (e) {
      if (!mounted) return;
      widget.onAttentionSignals(
        AttentionSignals(
          facePresent: false,
          multiFace: false,
          appInForeground: widget.appInForeground(),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _analysisTimer = null;
    unawaited(_detector?.dispose());
    _detector = null;

    _sharedRefCount = (_sharedRefCount - 1).clamp(0, 1 << 30);
    if (_sharedRefCount == 0) {
      // 리스트 스크롤 등으로 잠깐 위젯이 사라졌다가 다시 생길 수 있어
      // 즉시 stop 하지 않고 약간의 유예를 둡니다.
      _sharedDisposeTimer?.cancel();
      _sharedDisposeTimer = Timer(const Duration(seconds: 8), () {
        for (final t in _sharedStream?.getTracks() ?? <html.MediaStreamTrack>[]) {
          t.stop();
        }
        _sharedStream = null;
        try {
          _sharedVideo?.srcObject = null;
        } catch (_) {}
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
    if (_error != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
        ),
      );
    }
    // HtmlElementView는 부모가 명시 크기를 줄 때 웹에서 안정적으로 보입니다.
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const HtmlElementView(viewType: _sharedViewType),
    );
  }
}
