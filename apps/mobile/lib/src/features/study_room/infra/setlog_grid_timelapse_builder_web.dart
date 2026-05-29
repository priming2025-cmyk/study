// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'setlog_grid_timelapse_builder.dart';
import 'setlog_grid_timelapse_frames.dart';

/// 웹: iOS/Android와 동일한 그리드 합성 → Canvas + MediaRecorder → WebM 다운로드
abstract final class SetlogGridTimelapseBuilderImpl {
  static Future<String?> buildAndSave({required GridBuildInput input}) async {
    if (input.slots.isEmpty) return null;
    if (input.allPhotos.isEmpty &&
        !input.allClips.any((c) => c.posterUrl?.trim().isNotEmpty == true)) {
      return null;
    }

    final prep = await SetlogGridTimelapseFrames.prepare(input);
    if (prep.validHours.isEmpty) return null;

    final bytesCache =
        await SetlogGridTimelapseFrames.fetchAllBytes(SetlogGridTimelapseFrames.collectUrls(prep));

    final mimeType = _pickMime();
    if (mimeType == null) {
      debugPrint('[GridTimelapse web] MediaRecorder 미지원 브라우저');
      return null;
    }

    final canvas = html.CanvasElement(
      width: input.width,
      height: input.height,
    );
    final ctx = canvas.context2D;

    final chunks = <html.Blob>[];
    final recorder = html.MediaRecorder(
      canvas.captureStream(input.fps.toDouble()),
      {'mimeType': mimeType},
    );
    recorder.addEventListener('dataavailable', (html.Event e) {
      final blob = (e as html.BlobEvent).data;
      if (blob != null && blob.size > 0) chunks.add(blob);
    });

    final stopCompleter = Completer<void>();
    recorder.addEventListener('stop', (_) => stopCompleter.complete());
    recorder.start(100);

    final frameDelayMs = (1000 / input.fps).round();
    var globalFrameIndex = 0;

    try {
      final frameSpecs = SetlogGridTimelapseFrames.buildFrameSpecs(
        input: input,
        prep: prep,
      );
      if (frameSpecs.isEmpty) return null;

      for (final spec in frameSpecs) {
        final timeLabel =
            '${spec.hour.toString().padLeft(2, '0')}:${spec.minute.toString().padLeft(2, '0')}';

        final slots = SetlogGridTimelapseFrames.buildSlotFrames(
          input: input,
          prep: prep,
          bytesCache: bytesCache,
          hour: spec.hour,
          minute: spec.minute,
        );

        final rgba = await SetlogGridTimelapseFrames.renderGridFrame(
          slots: slots,
          hourLabel: timeLabel,
          width: input.width,
          height: input.height,
          streakDays: prep.streakDays,
          showStreak: globalFrameIndex == 0,
          showHourLabel: true,
        );

        if (rgba != null) {
          for (var r = 0; r < spec.repeat; r++) {
            _blitRgba(ctx, rgba, input.width, input.height);
            await Future<void>.delayed(Duration(milliseconds: frameDelayMs));
          }
        }
        globalFrameIndex++;
      }
    } catch (e, st) {
      debugPrint('[GridTimelapse web] 렌더 오류: $e\n$st');
    }

    recorder.stop();
    await stopCompleter.future;

    if (chunks.isEmpty) return null;

    final blob = html.Blob(chunks, mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'setudy_celolog.webm')
      ..click();
    html.Url.revokeObjectUrl(url);

    return 'downloaded';
  }

  static void _blitRgba(
    html.CanvasRenderingContext2D ctx,
    Uint8List rgba,
    int width,
    int height,
  ) {
    final imageData = ctx.createImageData(width, height);
    final dest = imageData.data;
    final len = rgba.length < dest.length ? rgba.length : dest.length;
    for (int i = 0; i < len; i++) {
      dest[i] = rgba[i];
    }
    ctx.putImageData(imageData, 0, 0);
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
