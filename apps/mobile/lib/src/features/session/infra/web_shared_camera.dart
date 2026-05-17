// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert' show base64Decode;
import 'dart:html' as html;
import 'dart:typed_data';

import 'web_face_detector_holder.dart';

/// 웹 전체에서 **카메라 스트림 1개**만 사용 (공부탭·셋터디·스냅샷 공유).
final class WebSharedCamera {
  WebSharedCamera._();
  static final WebSharedCamera instance = WebSharedCamera._();

  html.VideoElement? _video;
  html.MediaStream? _stream;
  Future<html.MediaStream?>? _openFuture;
  int _refs = 0;
  Timer? _disposeTimer;

  html.VideoElement? get video => _video;
  html.MediaStream? get stream => _stream;

  bool get isStreamReady =>
      _stream != null &&
      _video != null &&
      _video!.readyState >= html.MediaElement.HAVE_CURRENT_DATA &&
      _video!.videoWidth >= 8;

  Future<html.MediaStream?> acquire() {
    _refs++;
    _disposeTimer?.cancel();
    _disposeTimer = null;
    _openFuture ??= _open();
    return _openFuture!;
  }

  void release() {
    if (_refs <= 0) return;
    _refs--;
    if (_refs > 0) return;
    _disposeTimer?.cancel();
    _disposeTimer = Timer(const Duration(seconds: 12), () {
      if (_refs > 0) return;
      for (final t in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
        t.stop();
      }
      _stream = null;
      try {
        _video?.srcObject = null;
      } catch (_) {}
      _openFuture = null;
    });
  }

  Future<html.MediaStream?> _open() async {
    if (_stream != null && _video != null) return _stream;

    final md = html.window.navigator.mediaDevices;
    if (md == null) return null;

    _video ??= html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.display = 'block'
      ..style.objectFit = 'cover'
      ..style.transform = 'scaleX(-1)'
      ..style.width = '100%'
      ..style.height = '100%';

    // Safari: 복잡한 constraint 가 실패하는 경우가 있어 단순 요청 후 fallback.
    html.MediaStream stream;
    try {
      stream = await md.getUserMedia({'video': true, 'audio': false});
    } catch (_) {
      stream = await md.getUserMedia({'video': true});
    }

    _stream = stream;
    _video!.srcObject = stream;
    try {
      await _video!.play();
    } catch (_) {}

    for (var i = 0; i < 60; i++) {
      if (_video!.readyState >= html.MediaElement.HAVE_CURRENT_DATA &&
          _video!.videoWidth >= 8) {
        unawaited(WebFaceDetectorHolder.instance.warmUp());
        return _stream;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    unawaited(WebFaceDetectorHolder.instance.warmUp());
    return _stream;
  }

  Future<Uint8List?> captureJpeg({double maxDim = 480, double quality = 0.88}) async {
    final v = _video;
    if (v == null || v.readyState < html.MediaElement.HAVE_CURRENT_DATA) {
      return null;
    }
    final w = v.videoWidth;
    final h = v.videoHeight;
    if (w < 8 || h < 8) return null;

    late final double outW;
    late final double outH;
    if (w >= h) {
      outW = w > maxDim ? maxDim : w.toDouble();
      outH = h * (outW / w);
    } else {
      outH = h > maxDim ? maxDim : h.toDouble();
      outW = w * (outH / h);
    }

    final canvas =
        html.CanvasElement(width: outW.round(), height: outH.round());
    final ctx = canvas.context2D;
    ctx
      ..save()
      ..scale(outW / w, outH / h)
      ..drawImage(v, 0, 0)
      ..restore();

    final dataUrl = canvas.toDataUrl('image/jpeg', quality);
    final comma = dataUrl.indexOf(',');
    if (comma < 0 || comma >= dataUrl.length - 1) return null;
    return Uint8List.fromList(base64Decode(dataUrl.substring(comma + 1)));
  }
}
