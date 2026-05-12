// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// 웹: getUserMedia → canvas → JPEG 바이트로 스냅샷을 캡처합니다.
class RoomSnapshot {
  html.VideoElement? _video;
  html.MediaStream? _stream;
  bool _initialized = false;

  Future<void> initialize() async {
    try {
      final md = html.window.navigator.mediaDevices;
      if (md == null) return;
      final stream = await md.getUserMedia({'video': true, 'audio': false});
      _stream = stream;
      _video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..srcObject = stream;
      await _video!.play();
      // 스트림이 실제로 시작될 때까지 짧게 대기
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _initialized = true;
    } catch (_) {}
  }

  /// JPEG 바이트를 반환합니다. 실패하면 null.
  Future<Uint8List?> capture() async {
    final video = _video;
    if (!_initialized || video == null) return null;
    if (video.readyState < html.MediaElement.HAVE_CURRENT_DATA) return null;

    final w = video.videoWidth;
    final h = video.videoHeight;
    if (w < 4 || h < 4) return null;

    try {
      // 320px 폭으로 축소
      const maxW = 320.0;
      final scale = maxW / w;
      final outW = maxW.round();
      final outH = (h * scale).round();

      final canvas = html.CanvasElement(width: outW, height: outH);
      canvas.context2D
        ..save()
        ..scale(scale, scale)
        ..drawImage(video, 0, 0)
        ..restore();

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.72);
      final comma = dataUrl.indexOf(',');
      if (comma < 0 || comma >= dataUrl.length - 1) return null;
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    try {
      for (final t in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
        t.stop();
      }
    } catch (_) {}
    _stream = null;
    _video?.srcObject = null;
    _video = null;
    _initialized = false;
  }
}
