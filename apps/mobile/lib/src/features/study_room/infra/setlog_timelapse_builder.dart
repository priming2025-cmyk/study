import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/study_room_photo_snap_row.dart';
import '../domain/study_room_video_clip_row.dart';

class SetlogBuildInput {
  final List<StudyRoomPhotoSnapRow> photos;
  final List<StudyRoomVideoClipRow> clips;
  final DateTime downloadedAt;

  /// 3배속: 1분=0.1초 → fps=10, 1분당 1프레임
  final int fps;
  final int width;
  final int height;
  final int videoBitrate;

  const SetlogBuildInput({
    required this.photos,
    required this.clips,
    required this.downloadedAt,
    this.fps = 10,
    this.width = 720,
    this.height = 1280,
    this.videoBitrate = 850000,
  });
}

abstract final class SetlogTimelapseBuilder {
  static Future<String?> buildAndShare({
    required SetlogBuildInput input,
  }) async {
    if (kIsWeb) {
      return '웹에서는 “공부 끝! 영상” 생성이 아직 지원되지 않아요';
    }
    if (input.photos.isEmpty && input.clips.isEmpty) {
      return '오늘 저장된 사진/영상이 없어요';
    }

    final startAt = _minTime(input.photos, input.clips) ?? input.downloadedAt;
    final endAt = input.downloadedAt;

    // 프레임 소스: 1분 사진 + (10분) 영상 포스터
    final frames = <_FrameSource>[
      for (final p in input.photos) _FrameSource(time: p.recordedAt, imageUrl: p.publicUrl),
      for (final c in input.clips)
        if (c.posterUrl != null && c.posterUrl!.trim().isNotEmpty)
          _FrameSource(time: c.recordedAt, imageUrl: c.posterUrl!.trim(), label: '2초 영상'),
    ]..sort((a, b) => a.time.compareTo(b.time));

    // 너무 길면(저장 부담) 상한: 6시간(=360프레임)
    final maxFrames = 360;
    final trimmed = frames.length > maxFrames ? frames.sublist(frames.length - maxFrames) : frames;

    final dir = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/setudy_setlog_${endAt.toLocal().year}${endAt.toLocal().month.toString().padLeft(2, '0')}${endAt.toLocal().day.toString().padLeft(2, '0')}_${endAt.toLocal().hour.toString().padLeft(2, '0')}${endAt.toLocal().minute.toString().padLeft(2, '0')}.mp4';

    await FlutterQuickVideoEncoder.setup(
      width: input.width,
      height: input.height,
      fps: input.fps,
      videoBitrate: input.videoBitrate,
      profileLevel: ProfileLevel.baselineAutoLevel,
      audioBitrate: 0,
      audioChannels: 0,
      sampleRate: 0,
      filepath: outPath,
    );

    try {
      for (final f in trimmed) {
        final bytes = await _fetchBytes(f.imageUrl);
        if (bytes == null) continue;
        final rgba = await _renderFrameRgba(
          jpegBytes: bytes,
          width: input.width,
          height: input.height,
          startAt: startAt,
          endAt: endAt,
          downloadedAt: endAt,
          overlayLabel: f.label,
        );
        if (rgba == null) continue;
        await FlutterQuickVideoEncoder.appendVideoFrame(rgba);
      }
    } catch (e, st) {
      debugPrint('[SetlogTimelapse] $e\n$st');
      try {
        await FlutterQuickVideoEncoder.finish();
      } catch (_) {}
      return '영상 생성에 실패했어요: $e';
    }

    await FlutterQuickVideoEncoder.finish();

    final file = File(outPath);
    if (!await file.exists()) return '영상 파일을 만들지 못했어요';
    await SharePlus.instance.share(
      ShareParams(
        text: '공부 끝!\n시작: ${_fmt(startAt)}\n끝: ${_fmt(endAt)}\n다운로드: ${_fmt(endAt)}',
        files: [XFile(file.path)],
        subject: '셋로그',
      ),
    );
    return null;
  }

  static DateTime? _minTime(
    List<StudyRoomPhotoSnapRow> photos,
    List<StudyRoomVideoClipRow> clips,
  ) {
    DateTime? m;
    for (final p in photos) {
      if (m == null || p.recordedAt.isBefore(m)) m = p.recordedAt;
    }
    for (final c in clips) {
      if (m == null || c.recordedAt.isBefore(m)) m = c.recordedAt;
    }
    return m;
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

  static Future<Uint8List?> _renderFrameRgba({
    required Uint8List jpegBytes,
    required int width,
    required int height,
    required DateTime startAt,
    required DateTime endAt,
    required DateTime downloadedAt,
    String? overlayLabel,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        jpegBytes,
        targetWidth: width,
        targetHeight: height,
      );
      final fi = await codec.getNextFrame();
      final img = fi.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      );

      // cover-fit
      final paint = Paint();
      final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      final dst = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
      canvas.drawImageRect(img, src, dst, paint);

      // bottom gradient for text readability
      final grad = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, height.toDouble() * 0.72),
          Offset(0, height.toDouble()),
          [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.55),
          ],
        );
      canvas.drawRect(dst, grad);

      final textPainter = TextPainter(textDirection: TextDirection.ltr);
      final baseStyle = const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      );
      textPainter.text = TextSpan(
        style: baseStyle,
        text: '공부 끝!',
      );
      textPainter.layout(maxWidth: width.toDouble() - 32);
      textPainter.paint(canvas, Offset(16, height - 84));

      final small = TextPainter(textDirection: TextDirection.ltr);
      small.text = TextSpan(
        style: baseStyle.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.92),
        ),
        text:
            '시작 ${_fmt(startAt)}  ·  끝 ${_fmt(endAt)}  ·  다운로드 ${_fmt(downloadedAt)}',
      );
      small.layout(maxWidth: width.toDouble() - 32);
      small.paint(canvas, Offset(16, height - 54));

      if (overlayLabel != null && overlayLabel.trim().isNotEmpty) {
        final tag = TextPainter(textDirection: TextDirection.ltr);
        tag.text = TextSpan(
          style: baseStyle.copyWith(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          text: overlayLabel.trim(),
        );
        tag.layout(maxWidth: width.toDouble() - 32);
        tag.paint(canvas, Offset(16, 16));
      }

      final pic = recorder.endRecording();
      final out = await pic.toImage(width, height);
      final bd = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
      return bd?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[SetlogTimelapse] render: $e');
      return null;
    }
  }

  static String _fmt(DateTime t) {
    final l = t.toLocal();
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _FrameSource {
  final DateTime time;
  final String imageUrl;
  final String? label;
  const _FrameSource({required this.time, required this.imageUrl, this.label});
}

