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
  late final String _viewType;
  html.VideoElement? _video;
  html.MediaStream? _stream;
  String? _error;
  bool _registered = false;

  FaceDetector? _detector;
  Timer? _analysisTimer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'session-self-cam-${DateTime.now().microsecondsSinceEpoch}';
    _video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      // 인라인 비디오는 높이 0으로 잡히는 경우가 있어 block + 픽셀 크기를 둡니다.
      ..style.display = 'block'
      ..style.width = '${widget.width}px'
      ..style.height = '${widget.height}px'
      ..style.objectFit = 'cover'
      // 셀카처럼 거울 반전(실시간으로 내가 보는 방향과 맞춤)
      ..style.transform = 'scaleX(-1)';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _video!);
    _registered = true;
    _openCameraAndStartAnalysis();
  }

  @override
  void didUpdateWidget(SessionSelfCameraSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = _video;
    if (v != null &&
        (oldWidget.width != widget.width || oldWidget.height != widget.height)) {
      v.style.width = '${widget.width}px';
      v.style.height = '${widget.height}px';
    }
  }

  Future<void> _openCameraAndStartAnalysis() async {
    try {
      final md = html.window.navigator.mediaDevices;
      if (md == null) {
        setState(() => _error = '이 브라우저는 카메라를 지원하지 않아요.');
        return;
      }
      final stream = await md.getUserMedia({'video': true});
      _stream = stream;
      _video!.srcObject = stream;
      await _video!.play();

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
    for (final t in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
      t.stop();
    }
    _stream = null;
    _video?.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_registered || _video == null) {
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
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
