import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../domain/study_room_photo_snap_row.dart';
import 'setlog_grid_timelapse_builder.dart';

/// 그리드 타임랩스 1프레임(1명 슬롯) 데이터
class GridSlotFrame {
  final String? displayName;
  final String? statusText;
  final Uint8List? imageBytes;

  const GridSlotFrame({
    this.displayName,
    this.statusText,
    this.imageBytes,
  });
}

class GridTimelapsePrepareResult {
  final Map<String, Map<int, String>> photoMap;
  final List<int> validMinuteKeys;

  const GridTimelapsePrepareResult({
    required this.photoMap,
    required this.validMinuteKeys,
  });
}

class GridTimelapseFrameSpec {
  final int hour;
  final int minute;
  final int repeat;

  const GridTimelapseFrameSpec({
    required this.hour,
    required this.minute,
    required this.repeat,
  });
}

/// iOS/Android·웹 공통: 데이터 준비 + 그리드 프레임 렌더링
abstract final class SetlogGridTimelapseFrames {
  static const _introOutroSeconds = 2;

  static Future<GridTimelapsePrepareResult> prepare(GridBuildInput input) async {
    final photoMap = buildPhotoMap(input.allPhotos);
    final keys = <int>{};
    for (final um in photoMap.values) {
      keys.addAll(um.keys);
    }
    final validMinuteKeys = keys.toList()..sort();
    return GridTimelapsePrepareResult(
      photoMap: photoMap,
      validMinuteKeys: validMinuteKeys,
    );
  }

  static Set<String> collectUrls(GridTimelapsePrepareResult prep) {
    final allUrls = <String>{};
    for (final um in prep.photoMap.values) {
      allUrls.addAll(um.values);
    }
    return allUrls;
  }

  static List<GridTimelapseFrameSpec> buildFrameSpecs({
    required GridBuildInput input,
    required GridTimelapsePrepareResult prep,
  }) {
    final repeat = input.speed.frameRepeatAt(encoderFps: input.fps);
    return [
      for (final key in prep.validMinuteKeys)
        GridTimelapseFrameSpec(
          hour: key ~/ 60,
          minute: key % 60,
          repeat: repeat,
        ),
    ];
  }

  static int introOutroFrameCount(GridBuildInput input) =>
      _introOutroSeconds * input.fps;

  static List<GridSlotFrame> buildSlotFrames({
    required GridBuildInput input,
    required GridTimelapsePrepareResult prep,
    required Map<String, Uint8List> bytesCache,
    required int hour,
    required int minute,
  }) {
    final minuteKey = hour * 60 + minute;
    final frames = <GridSlotFrame>[];

    for (final slot in input.slots) {
      final photoUrl = prep.photoMap[slot.userId]?[minuteKey];
      final snap = photoUrl != null
          ? findSnap(input.allPhotos, slot.userId, minuteKey)
          : null;
      final imageBytes =
          photoUrl != null ? bytesCache[photoUrl] : null;
      final rawStatus = snap?.statusText?.trim();
      final statusText = imageBytes != null &&
              rawStatus != null &&
              rawStatus.isNotEmpty
          ? rawStatus
          : null;

      frames.add(GridSlotFrame(
        displayName: slot.displayName,
        statusText: statusText,
        imageBytes: imageBytes,
      ));
    }
    return frames;
  }

  static Map<String, Map<int, String>> buildPhotoMap(
    List<StudyRoomPhotoSnapRow> photos,
  ) {
    final map = <String, Map<int, String>>{};
    for (final p in photos) {
      final local = p.recordedAt.toLocal();
      final key = local.hour * 60 + local.minute;
      (map[p.userId] ??= {})[key] = p.publicUrl;
    }
    return map;
  }

  static StudyRoomPhotoSnapRow? findSnap(
    List<StudyRoomPhotoSnapRow> photos,
    String userId,
    int minuteKey,
  ) {
    for (final p in photos) {
      if (p.userId != userId) continue;
      final local = p.recordedAt.toLocal();
      if (local.hour * 60 + local.minute == minuteKey) return p;
    }
    return null;
  }

  static Future<Map<String, Uint8List>> fetchAllBytes(Set<String> urls) async {
    final result = <String, Uint8List>{};
    await Future.wait(
      urls.map((url) async {
        try {
          final uri = Uri.parse(url);
          var res = await http.get(uri);
          if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
            final stripped = uri.replace(queryParameters: {});
            if (stripped.toString() != uri.toString()) {
              res = await http.get(stripped);
            }
          }
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            result[url] = res.bodyBytes;
          }
        } catch (_) {}
      }),
      eagerError: false,
    );
    return result;
  }

  static String formatDateTitle(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}년 ${l.month}월 ${l.day}일';
  }

  static Future<Uint8List?> renderTitleFrame({
    required DateTime date,
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF0D0D1A),
    );
    _drawCenteredLabel(
      canvas,
      formatDateTitle(date),
      Offset(width / 2, height * 0.42),
      28,
      color: const Color(0xCCFFFFFF),
      fontWeight: FontWeight.w800,
    );
    _drawCenteredLabel(
      canvas,
      'SETUDY',
      Offset(width / 2, height * 0.52),
      36,
      color: const Color(0xEEFFFFFF),
      fontWeight: FontWeight.w900,
      letterSpacing: 6,
    );
    return _finishFrame(recorder, width, height);
  }

  static Future<Uint8List?> renderOutroFrame({
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF0D0D1A),
    );
    _drawCenteredLabel(
      canvas,
      '오늘도\n우리\n함께',
      Offset(width / 2, height * 0.48),
      32,
      color: const Color(0xDDFFFFFF),
      fontWeight: FontWeight.w800,
      maxLines: 3,
    );
    return _finishFrame(recorder, width, height);
  }

  static Future<Uint8List?> renderGridFrame({
    required List<GridSlotFrame> slots,
    required String hourLabel,
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF0D0D1A),
    );

    final rects =
        layoutRects(slots.length, width.toDouble(), height.toDouble());

    for (int i = 0; i < slots.length; i++) {
      if (i >= rects.length) break;
      final rect = rects[i];
      final slot = slots[i];

      if (slot.imageBytes != null) {
        try {
          final codec = await ui.instantiateImageCodec(
            slot.imageBytes!,
            targetWidth: rect.width.round(),
            targetHeight: rect.height.round(),
          );
          final fi = await codec.getNextFrame();
          final img = fi.image;
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(
              0,
              0,
              img.width.toDouble(),
              img.height.toDouble(),
            ),
            rect,
            Paint(),
          );
          img.dispose();

          final grad = Paint()
            ..shader = ui.Gradient.linear(
              Offset(rect.left, rect.bottom - rect.height * 0.35),
              Offset(rect.left, rect.bottom),
              [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
            );
          canvas.drawRect(rect, grad);
        } catch (_) {
          _drawAbsent(canvas, rect, slot.displayName);
        }

        if (slot.statusText?.trim().isNotEmpty == true) {
          _drawCenteredLabel(
            canvas,
            slot.statusText!.trim(),
            rect.center,
            20,
            color: const Color(0xB3FFFFFF),
            fontWeight: FontWeight.w800,
            maxWidth: rect.width - 16,
          );
        }
      } else {
        _drawAbsent(canvas, rect, slot.displayName);
      }

      final name = slot.displayName?.trim();
      if (name != null && name.isNotEmpty) {
        _drawCornerLabel(canvas, name, Offset(rect.left + 8, rect.top + 8));
      }

      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0x44FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }

    _drawTopHourLabel(canvas, hourLabel, width.toDouble());

    return _finishFrame(recorder, width, height);
  }

  static Future<Uint8List?> _finishFrame(
    ui.PictureRecorder recorder,
    int width,
    int height,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  static List<Rect> layoutRects(int n, double w, double h) {
    if (n <= 0) return const [];
    if (n == 1) return [Rect.fromLTWH(0, 0, w, h)];
    if (n == 2) {
      return [
        Rect.fromLTWH(0, 0, w, h / 2),
        Rect.fromLTWH(0, h / 2, w, h / 2),
      ];
    }
    if (n == 3) {
      return [
        Rect.fromLTWH(0, 0, w, h / 2),
        Rect.fromLTWH(0, h / 2, w / 2, h / 2),
        Rect.fromLTWH(w / 2, h / 2, w / 2, h / 2),
      ];
    }
    if (n == 4) {
      return [
        Rect.fromLTWH(0, 0, w / 2, h / 2),
        Rect.fromLTWH(w / 2, 0, w / 2, h / 2),
        Rect.fromLTWH(0, h / 2, w / 2, h / 2),
        Rect.fromLTWH(w / 2, h / 2, w / 2, h / 2),
      ];
    }
    if (n == 5) {
      return [
        Rect.fromLTWH(0, 0, w, h / 2),
        Rect.fromLTWH(0, h / 2, w / 2, h / 4),
        Rect.fromLTWH(w / 2, h / 2, w / 2, h / 4),
        Rect.fromLTWH(0, 3 * h / 4, w / 2, h / 4),
        Rect.fromLTWH(w / 2, 3 * h / 4, w / 2, h / 4),
      ];
    }
    final rows = ((n + 1) ~/ 2);
    final cellH = h / rows;
    return [
      for (int i = 0; i < n; i++)
        Rect.fromLTWH(
          (i % 2 == 0) ? 0 : w / 2,
          (i ~/ 2) * cellH,
          (i == n - 1 && n.isOdd) ? w : w / 2,
          cellH,
        ),
    ];
  }

  static String nowTag(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}${l.month.toString().padLeft(2, '0')}'
        '${l.day.toString().padLeft(2, '0')}_'
        '${l.hour.toString().padLeft(2, '0')}'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  static void _drawAbsent(Canvas canvas, Rect rect, String? name) {
    canvas.drawRect(rect, Paint()..color = const Color(0xFF1A1A2E));
    _drawCenteredLabel(
      canvas,
      '자리비움',
      rect.center,
      16,
      color: const Color(0xFF555577),
    );
    if (name?.isNotEmpty == true) {
      _drawCornerLabel(canvas, name!, Offset(rect.left + 8, rect.top + 8));
    }
  }

  static void _drawCenteredLabel(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize, {
    Color color = const Color(0xCCFFFFFF),
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = 0,
    double maxWidth = 200,
    int maxLines = 2,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: 1.15,
          shadows: const [
            Shadow(blurRadius: 4, color: Color(0xAA000000)),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  static void _drawCornerLabel(Canvas canvas, String text, Offset topLeft) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xEEFFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          shadows: [Shadow(blurRadius: 3, color: Color(0xBB000000))],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 120);
    tp.paint(canvas, topLeft);
  }

  static void _drawTopHourLabel(Canvas canvas, String label, double width) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xB3FFFFFF),
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          shadows: [Shadow(blurRadius: 6, color: Color(0xAA000000))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    tp.paint(canvas, Offset((width - tp.width) / 2, 12));
  }
}
