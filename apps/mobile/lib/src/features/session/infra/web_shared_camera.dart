// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert' show base64Decode;
import 'dart:html' as html;
import 'dart:typed_data';

/// 웹 전체에서 **카메라 스트림 1개**만 사용 (공부탭·셋터디·스냅샷 공유).
///
/// iOS Safari는 [getUserMedia]를 동시에 여러 번 호출하면 매우 느리거나 실패합니다.
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
    if (_stream != null) return _stream;
    final md = html.window.navigator.mediaDevices;
    if (md == null) return null;

    _video ??= html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.display = 'block'
      ..style.objectFit = 'cover'
      ..style.transform = 'scaleX(-1)';

    final stream = await md.getUserMedia({
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
      },
      'audio': false,
    });
    _stream = stream;
    _video!.srcObject = stream;
    try {
      await _video!.play();
    } catch (_) {}

    for (var i = 0; i < 50; i++) {
      if (_video!.readyState >= html.MediaElement.HAVE_CURRENT_DATA &&
          _video!.videoWidth >= 8) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return _stream;
  }

  /// 공유 비디오에서 JPEG 캡처 (스냅샷·분석 공용).
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
