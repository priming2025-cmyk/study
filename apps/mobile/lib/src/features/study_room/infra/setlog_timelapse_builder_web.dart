import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'setlog_timelapse_builder.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

abstract final class SetlogTimelapseBuilderImpl {
  static Future<String?> buildAndShare({
    required SetlogBuildInput input,
  }) async {
    if (input.photos.isEmpty && input.clips.isEmpty) {
      // 요구사항: 안내/팝업 없이 조용히 종료
      return null;
    }

    // 웹: Canvas + MediaRecorder → WebM 만들고 바로 다운로드.
    final frames = <_FrameSource>[
      for (final p in input.photos)
        _FrameSource(time: p.recordedAt, imageUrl: p.publicUrl),
      for (final c in input.clips)
        if ((c.posterUrl ?? '').trim().isNotEmpty)
          _FrameSource(
            time: c.recordedAt,
            imageUrl: c.posterUrl!.trim(),
            label: '2초 영상',
          ),
    ]..sort((a, b) => a.time.compareTo(b.time));

    final maxFrames = 360;
    final trimmed = frames.length > maxFrames
        ? frames.sublist(frames.length - maxFrames)
        : frames;
    if (trimmed.isEmpty) return null;

    final width = input.width;
    final height = input.height;
    final fps = input.fps <= 0 ? 10 : input.fps;

    final canvas = html.CanvasElement(width: width, height: height);
    final ctx = canvas.context2D;

    final stream = canvas.captureStream(fps);
    final mime = _pickMime();
    final recorder = html.MediaRecorder(
      stream,
      {
        'mimeType': mime,
        'videoBitsPerSecond': input.videoBitrate,
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

    // 각 프레임을 캔버스에 그리면서 일정 FPS로 흘려보내면,
    // MediaRecorder가 “영상”으로 묶어줍니다.
    for (final f in trimmed) {
      final bytes = await _fetchBytes(f.imageUrl);
      if (bytes == null) continue;
      await _drawCoverJpeg(ctx, bytes, width: width, height: height);
      // 1 프레임 시간만큼 대기
      await Future<void>.delayed(Duration(milliseconds: (1000 / fps).round()));
    }

    recorder.stop();
    await done.future.timeout(const Duration(seconds: 8), onTimeout: () {});

    if (chunks.isEmpty) return null;
    final blob = html.Blob(chunks, mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    try {
      final endAt = input.downloadedAt.toLocal();
      final name =
          'setudy_setlog_${endAt.year}${endAt.month.toString().padLeft(2, '0')}${endAt.day.toString().padLeft(2, '0')}_${endAt.hour.toString().padLeft(2, '0')}${endAt.minute.toString().padLeft(2, '0')}.webm';
      final a = html.AnchorElement(href: url)
        ..download = name
        ..style.display = 'none';
      html.document.body?.append(a);
      a.click();
      a.remove();
    } finally {
      html.Url.revokeObjectUrl(url);
    }
    return null;
  }

  static String _pickMime() {
    final candidates = <String>[
      'video/webm;codecs=vp9',
      'video/webm;codecs=vp8',
      'video/webm',
    ];
    for (final c in candidates) {
      if (html.MediaRecorder.isTypeSupported(c)) return c;
    }
    return 'video/webm';
  }

  static Future<Uint8List?> _fetchBytes(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _drawCoverJpeg(
    html.CanvasRenderingContext2D ctx,
    Uint8List bytes, {
    required int width,
    required int height,
  }) async {
    final blob = html.Blob([bytes], 'image/jpeg');
    final url = html.Url.createObjectUrlFromBlob(blob);
    try {
      final img = html.ImageElement(src: url);
      await img.onLoad.first.timeout(const Duration(seconds: 8));
      ctx
        ..save()
        ..clearRect(0, 0, width.toDouble(), height.toDouble());

      // cover-fit
      final iw = img.naturalWidth.toDouble();
      final ih = img.naturalHeight.toDouble();
      if (iw < 2 || ih < 2) {
        ctx.restore();
        return;
      }
      final scale = (width / iw > height / ih) ? (width / iw) : (height / ih);
      final dw = iw * scale;
      final dh = ih * scale;
      final dx = (width - dw) / 2;
      final dy = (height - dh) / 2;
      ctx.drawImageScaled(img, dx, dy, dw, dh);
      ctx.restore();
    } catch (_) {
      // ignore
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }
}

class _FrameSource {
  final DateTime time;
  final String imageUrl;
  final String? label;
  const _FrameSource({required this.time, required this.imageUrl, this.label});
}

