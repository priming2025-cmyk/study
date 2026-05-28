// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'setlog_grid_timelapse_builder.dart';

/// 웹에서는 Canvas + MediaRecorder로 WebM을 생성해 다운로드합니다.
/// 그리드 합성은 OffscreenCanvas 대신 표준 Canvas를 사용합니다.
abstract final class SetlogGridTimelapseBuilderImpl {
  static Future<String?> buildAndSave({required GridBuildInput input}) async {
    if (input.allPhotos.isEmpty && input.allClips.isEmpty) return null;

    // 사진/클립 URL 수집
    final photoUrls = input.allPhotos.map((p) => p.publicUrl).toSet();
    final clipUrls =
        input.allClips.where((c) => c.posterUrl?.isNotEmpty == true)
            .map((c) => c.posterUrl!)
            .toSet();

    if (photoUrls.isEmpty && clipUrls.isEmpty) return null;

    // 간단 구현: 모든 사진을 시간순으로 나열한 슬라이드쇼 WebM 다운로드
    // 브라우저 Canvas API 제약으로 그리드 합성은 단순화합니다.
    final allUrls = [...photoUrls, ...clipUrls];
    final bytes = await _fetchFirst(allUrls);
    if (bytes == null) return null;

    final canvas = html.CanvasElement(width: input.width, height: input.height);
    final ctx = canvas.context2D;

    final mimeType = _pickMime();
    if (mimeType == null) {
      debugPrint('[GridTimelapse web] MediaRecorder 미지원 브라우저');
      return null;
    }

    final chunks = <html.Blob>[];
    final recorder = html.MediaRecorder(
      canvas.captureStream(input.fps.toDouble()),
      {'mimeType': mimeType},
    );
    recorder.addEventListener('dataavailable', (html.Event e) {
      final blob = (e as html.BlobEvent).data;
      if (blob != null && blob.size > 0) chunks.add(blob);
    });
    final completer = Completer<void>();
    recorder.addEventListener('stop', (_) => completer.complete());
    recorder.start(100);

    for (final url in allUrls.take(120)) {
      try {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) {
          final blob = html.Blob([Uint8List.fromList(res.bodyBytes)]);
          final objUrl = html.Url.createObjectUrlFromBlob(blob);
          final img = html.ImageElement(src: objUrl);
          await img.onLoad.first;
          ctx.drawImageScaled(img, 0, 0, input.width, input.height);
          html.Url.revokeObjectUrl(objUrl);
          await Future<void>.delayed(
              Duration(milliseconds: (1000 / input.fps).round()));
        }
      } catch (_) {}
    }

    recorder.stop();
    await completer.future;

    if (chunks.isEmpty) return null;

    final blob = html.Blob(chunks, mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final a = html.AnchorElement(href: url)
      ..setAttribute('download', 'setudy_celolog.webm')
      ..click();
    html.Url.revokeObjectUrl(url);

    return 'downloaded';
  }

  static Future<Uint8List?> _fetchFirst(List<String> urls) async {
    for (final url in urls) {
      try {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return res.bodyBytes;
        }
      } catch (_) {}
    }
    return null;
  }

  static String? _pickMime() {
    const candidates = [
      'video/webm;codecs=vp9',
      'video/webm;codecs=vp8',
      'video/webm',
    ];
    for (final m in candidates) {
      if (html.MediaRecorder.isTypeSupported(m)) return m;
    }
    return null;
  }
}
