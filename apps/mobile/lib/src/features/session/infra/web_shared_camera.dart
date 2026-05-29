// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert' show base64Decode;
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../study_room/domain/study_video_clip_config.dart';
import 'web_face_detector_holder.dart';

/// 웹 전체에서 **카메라 스트림 1개**만 사용 (공부탭·셋터디·스냅샷 공유).
///
/// Safari는 [getUserMedia]를 **사용자 탭 직후** 호출해야 합니다.
/// [openFromUserGesture]를 버튼 [onPressed]에서 동기적으로 호출하세요.
final class WebSharedCamera {
  WebSharedCamera._();
  static final WebSharedCamera instance = WebSharedCamera._();

  html.VideoElement? _video;
  html.MediaStream? _stream;
  Future<html.MediaStream?>? _openFuture;
  int _refs = 0;
  Timer? _disposeTimer;
  String? _lastOpenError;

  html.VideoElement? get video => _video;
  html.MediaStream? get stream => _stream;
  String? get lastOpenError => _lastOpenError;

  bool get isStreamReady =>
      _stream != null &&
      _video != null &&
      _video!.readyState >= html.MediaElement.HAVE_CURRENT_DATA &&
      _video!.videoWidth >= 8 &&
      _tracksLive;

  bool get _tracksLive {
    final stream = _stream;
    if (stream == null) return false;
    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) return false;
    return tracks.every((t) => t.readyState == 'live');
  }

  /// `공부 시작`·방 입장 등 버튼 핸들러 **맨 앞**에서 동기 호출 (Safari 필수).
  void openFromUserGesture() {
    _disposeTimer?.cancel();
    _disposeTimer = null;
    if (_stream != null && isStreamReady) return;
    _openFuture ??= _open();
  }

  Future<html.MediaStream?> acquire() async {
    _refs++;
    _disposeTimer?.cancel();
    _disposeTimer = null;

    if (_stream != null && (!isStreamReady || !_tracksLive)) {
      debugPrint('[WebSharedCamera] stale stream → reopen');
      _teardown();
    }

    if (_stream != null && isStreamReady) {
      return _stream;
    }

    if (_openFuture != null) {
      try {
        final s = await _openFuture!;
        if (s != null && isStreamReady) return s;
      } catch (e) {
        debugPrint('[WebSharedCamera] await open: $e');
      }
    }

    _openFuture = _open();
    try {
      return await _openFuture!;
    } catch (e, st) {
      debugPrint('[WebSharedCamera] acquire failed: $e\n$st');
      _openFuture = null;
      return null;
    }
  }

  void release() {
    if (_refs <= 0) return;
    _refs--;
    if (_refs > 0) return;
    _scheduleDispose();
  }

  /// 세션 종료·방 퇴장 시 즉시 카메라를 끕니다.
  void forceRelease() {
    _refs = 0;
    _disposeTimer?.cancel();
    _disposeTimer = null;
    _teardown();
  }

  /// 연속 공부 사이에는 스트림을 잠시 유지(재허용·재연결 부담 감소).
  static const _idleDisposeDelay = Duration(minutes: 10);

  void _scheduleDispose() {
    _disposeTimer?.cancel();
    _disposeTimer = Timer(_idleDisposeDelay, () {
      if (_refs > 0) return;
      _teardown();
    });
  }

  void _teardown() {
    for (final t in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
      t.stop();
    }
    _stream = null;
    try {
      _video?.srcObject = null;
    } catch (_) {}
    _video = null;
    _openFuture = null;
    _lastOpenError = null;
  }

  Future<html.MediaStream?> _open() async {
    _lastOpenError = null;

    final md = html.window.navigator.mediaDevices;
    if (md == null) {
      _lastOpenError = 'mediaDevices 없음';
      _openFuture = null;
      return null;
    }

    _video ??= html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.display = 'block'
      ..style.objectFit = 'cover'
      ..style.transform = 'scaleX(-1)'
      ..style.width = '100%'
      ..style.height = '100%';

    html.MediaStream? stream;
    try {
      stream = await md.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
        'audio': false,
      });
    } catch (e) {
      debugPrint('[WebSharedCamera] constraint getUserMedia: $e');
      try {
        stream = await md.getUserMedia({'video': true, 'audio': false});
      } catch (e2) {
        _lastOpenError = '$e2';
        debugPrint('[WebSharedCamera] fallback getUserMedia: $e2');
        _openFuture = null;
        rethrow;
      }
    }

    _stream = stream;
    _video!.srcObject = stream;
    try {
      await _video!.play();
    } catch (e) {
      debugPrint('[WebSharedCamera] video.play: $e');
    }

    for (var i = 0; i < 80; i++) {
      if (isStreamReady) {
        unawaited(WebFaceDetectorHolder.instance.warmUp());
        return _stream;
      }
      // Safari: 트랙은 살아 있는데 readyState가 늦게 오르는 경우 재생 재시도
      if (i == 20 || i == 40) {
        try {
          await _video!.play();
        } catch (_) {}
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

  /// 2.5초 WebM (VP8·무음·저비트레이트) — 업로드 후 서버 24h 보관.
  Future<Uint8List?> recordWebmClip({
    Duration duration = StudyVideoClipConfig.recordDuration,
  }) async {
    final stream = _stream;
    if (stream == null || !isStreamReady) return null;

    final candidates = <String>[
      'video/webm;codecs=vp8',
      'video/webm',
    ];
    String? mime;
    for (final c in candidates) {
      if (html.MediaRecorder.isTypeSupported(c)) {
        mime = c;
        break;
      }
    }
    mime ??= 'video/webm';

    final recorder = html.MediaRecorder(
      stream,
      {
        'mimeType': mime,
        'videoBitsPerSecond': StudyVideoClipConfig.webVideoBitsPerSecond,
      },
    );

    final chunks = <html.Blob>[];
    final done = Completer<void>();
    recorder.addEventListener('dataavailable', (event) {
      final blob = (event as html.BlobEvent).data;
      if (blob != null && blob.size > 0) chunks.add(blob);
    });
    recorder.addEventListener('stop', (_) {
      if (!done.isCompleted) done.complete();
    });

    recorder.start(200);
    await Future<void>.delayed(duration);
    recorder.stop();
    await done.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );

    if (chunks.isEmpty) {
      return _recordWebmClipFromCanvas(duration: duration, mime: mime);
    }
    final blob = html.Blob(chunks, mime);
    final reader = html.FileReader();
    final bytesDone = Completer<Uint8List?>();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        bytesDone.complete(Uint8List.view(result));
      } else {
        bytesDone.complete(null);
      }
    });
    reader.readAsArrayBuffer(blob);
    return bytesDone.future.timeout(const Duration(seconds: 12));
  }

  /// MediaRecorder(stream) 실패 시 video 캔버스 캡처 스트림으로 녹화.
  Future<Uint8List?> _recordWebmClipFromCanvas({
    required Duration duration,
    required String mime,
  }) async {
    final v = _video;
    if (v == null || v.videoWidth < 8) return null;

    try {
      final canvas = html.CanvasElement(
        width: v.videoWidth,
        height: v.videoHeight,
      );
      final ctx = canvas.context2D;
      final stream = canvas.captureStream(12);
      final recorder = html.MediaRecorder(
        stream,
        {
          'mimeType': mime,
          'videoBitsPerSecond': StudyVideoClipConfig.webVideoBitsPerSecond,
        },
      );

      final chunks = <html.Blob>[];
      final done = Completer<void>();
      recorder.addEventListener('dataavailable', (event) {
        final blob = (event as html.BlobEvent).data;
        if (blob != null && blob.size > 0) chunks.add(blob);
      });
      recorder.addEventListener('stop', (_) {
        if (!done.isCompleted) done.complete();
      });

      recorder.start(200);
      final endAt = DateTime.now().add(duration);
      while (DateTime.now().isBefore(endAt)) {
        ctx.drawImage(v, 0, 0);
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      recorder.stop();
      await done.future.timeout(const Duration(seconds: 8), onTimeout: () {});

      if (chunks.isEmpty) return null;
      final blob = html.Blob(chunks, mime);
      final reader = html.FileReader();
      final bytesDone = Completer<Uint8List?>();
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is ByteBuffer) {
          bytesDone.complete(Uint8List.view(result));
        } else {
          bytesDone.complete(null);
        }
      });
      reader.readAsArrayBuffer(blob);
      return bytesDone.future.timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('[WebSharedCamera] canvas record: $e');
      return null;
    }
  }
}
