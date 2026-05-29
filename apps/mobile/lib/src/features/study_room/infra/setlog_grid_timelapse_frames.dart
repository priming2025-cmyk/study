import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/study_room_photo_snap_row.dart';
import '../domain/study_room_video_clip_row.dart';
import '../domain/study_video_clip_config.dart';
import 'setlog_grid_timelapse_builder.dart';

/// 그리드 타임랩스 1프레임(1명 슬롯) 데이터
class GridSlotFrame {
  final String? displayName;
  final String? statusText;
  final Uint8List? imageBytes;
  final int? focusPercent;

  const GridSlotFrame({
    this.displayName,
    this.statusText,
    this.imageBytes,
    this.focusPercent,
  });
}

class GridTimelapsePrepareResult {
  final Map<String, Map<int, String>> photoMap;
  final Map<String, Map<int, String>> clipMap;
  final List<int> validHours;
  final Map<String, Map<int, int>> focusByUserHour;
  final int streakDays;

  const GridTimelapsePrepareResult({
    required this.photoMap,
    required this.clipMap,
    required this.validHours,
    required this.focusByUserHour,
    required this.streakDays,
  });
}

/// 1시간 타임랩스에서 실제로 인코딩할 분·반복 횟수 (2초 클립은 3배속 ≈ 10프레임).
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
  static Future<GridTimelapsePrepareResult> prepare(GridBuildInput input) async {
    final photoMap = buildPhotoMap(input.allPhotos);
    final clipMap = buildClipMap(input.allClips);
    final allHours = getValidHours(input.allPhotos, input.allClips);
    final prepWithoutHours = GridTimelapsePrepareResult(
      photoMap: photoMap,
      clipMap: clipMap,
      validHours: allHours,
      focusByUserHour: buildFocusByUserHour(
        slots: input.slots,
        photos: input.allPhotos,
        clips: input.allClips,
      ),
      streakDays: await updateAndGetStreakDays(input.downloadedAt),
    );
    final activeHours = allHours
        .where((h) => buildFrameSpecs(input: input, prep: prepWithoutHours)
            .any((s) => s.hour == h))
        .toList();
    return GridTimelapsePrepareResult(
      photoMap: photoMap,
      clipMap: clipMap,
      validHours: activeHours,
      focusByUserHour: prepWithoutHours.focusByUserHour,
      streakDays: prepWithoutHours.streakDays,
    );
  }

  static Set<String> collectUrls(GridTimelapsePrepareResult prep) {
    final allUrls = <String>{};
    for (final um in prep.photoMap.values) {
      allUrls.addAll(um.values);
    }
    for (final um in prep.clipMap.values) {
      allUrls.addAll(um.values);
    }
    return allUrls;
  }

  static List<GridSlotFrame> buildSlotFrames({
    required GridBuildInput input,
    required GridTimelapsePrepareResult prep,
    required Map<String, Uint8List> bytesCache,
    required int hour,
    required int minute,
  }) {
    final minuteKey = hour * 60 + minute;
    final clipKey = hour * 60 + (minute ~/ 10) * 10;
    final frames = <GridSlotFrame>[];

    for (final slot in input.slots) {
      // 캡쳐 모드: 1분 1장 사진. 2초 영상 모드: 10분 슬롯(0·10·20…) 포스터만.
      final photoUrl = prep.photoMap[slot.userId]?[minuteKey];
      final String? clipUrl;
      if ((minute % 10) == 0) {
        clipUrl = prep.clipMap[slot.userId]?[clipKey];
      } else {
        clipUrl = null;
      }
      final url = photoUrl ?? clipUrl;

      final snap = photoUrl != null
          ? findSnap(input.allPhotos, slot.userId, minuteKey)
          : null;
      final imageBytes =
          url != null ? bytesCache[url] : null;
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
        focusPercent: prep.focusByUserHour[slot.userId]?[hour],
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

  static Map<String, Map<int, String>> buildClipMap(
    List<StudyRoomVideoClipRow> clips,
  ) {
    final map = <String, Map<int, String>>{};
    for (final c in clips) {
      final url = c.posterUrl;
      if (url == null || url.isEmpty) continue;
      final local = c.recordedAt.toLocal();
      // 10분 슬롯(0·10·20…)에 맞춰 저장 — 촬영 시각이 :03이어도 :00 블록에 매핑
      final key = local.hour * 60 + (local.minute ~/ 10) * 10;
      (map[c.userId] ??= {})[key] = url;
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

  static List<int> getValidHours(
    List<StudyRoomPhotoSnapRow> photos,
    List<StudyRoomVideoClipRow> clips,
  ) {
    final hours = <int>{};
    for (final p in photos) {
      hours.add(p.recordedAt.toLocal().hour);
    }
    for (final c in clips) {
      if (c.posterUrl?.isNotEmpty == true) {
        hours.add(c.recordedAt.toLocal().hour);
      }
    }
    return hours.toList()..sort();
  }

  /// 2초 클립(≈2.5초)을 3배속으로 4초/시간에 맞추기 위한 프레임 반복 수.
  static int clipBurstFrameCount(int fps) =>
      ((StudyVideoClipConfig.slotDurationMs / 1000.0) / 3.0 * fps).round().clamp(8, 16);

  static bool minuteHasMedia({
    required GridBuildInput input,
    required GridTimelapsePrepareResult prep,
    required int hour,
    required int minute,
  }) {
    final minuteKey = hour * 60 + minute;
    final clipKey = hour * 60 + (minute ~/ 10) * 10;
    for (final slot in input.slots) {
      if (prep.photoMap[slot.userId]?[minuteKey] != null) return true;
      if (prep.clipMap[slot.userId]?[clipKey] != null &&
          minute % 10 == 0) {
        return true;
      }
    }
    return false;
  }

  static bool minuteHasClipBurst({
    required GridBuildInput input,
    required GridTimelapsePrepareResult prep,
    required int hour,
    required int minute,
  }) {
    if (minute % 10 != 0) return false;
    final clipKey = hour * 60 + minute;
    for (final slot in input.slots) {
      if (prep.clipMap[slot.userId]?[clipKey] != null) return true;
    }
    return false;
  }

  static List<GridTimelapseFrameSpec> buildFrameSpecs({
    required GridBuildInput input,
    required GridTimelapsePrepareResult prep,
  }) {
    final burst = clipBurstFrameCount(input.fps);
    final specs = <GridTimelapseFrameSpec>[];

    for (final hour in prep.validHours) {
      for (var minute = 0; minute < 60; minute++) {
        if (!minuteHasMedia(
          input: input,
          prep: prep,
          hour: hour,
          minute: minute,
        )) {
          continue;
        }
        final repeat = minuteHasClipBurst(
          input: input,
          prep: prep,
          hour: hour,
          minute: minute,
        )
            ? burst
            : 1;
        specs.add(GridTimelapseFrameSpec(
          hour: hour,
          minute: minute,
          repeat: repeat,
        ));
      }
    }
    return specs;
  }

  static Map<String, Map<int, int>> buildFocusByUserHour({
    required List<GridMemberSlot> slots,
    required List<StudyRoomPhotoSnapRow> photos,
    required List<StudyRoomVideoClipRow> clips,
  }) {
    final focusScoresByUserHour = <String, Map<int, List<int>>>{};
    final photoMinutesByUserHour = <String, Map<int, Set<int>>>{};
    for (final p in photos) {
      final l = p.recordedAt.toLocal();
      final h = l.hour;
      final m = l.minute;
      final fs = p.focusScore;
      if (fs != null) {
        (focusScoresByUserHour[p.userId] ??= {})[h] ??= <int>[];
        focusScoresByUserHour[p.userId]![h]!.add(fs.clamp(0, 100));
      }
      (photoMinutesByUserHour[p.userId] ??= {})[h] ??= <int>{};
      photoMinutesByUserHour[p.userId]![h]!.add(m);
    }

    final clipBlocksByUserHour = <String, Map<int, Set<int>>>{};
    for (final c in clips) {
      if (c.posterUrl?.isNotEmpty != true) continue;
      final l = c.recordedAt.toLocal();
      final h = l.hour;
      final block = (l.minute ~/ 10) * 10;
      (clipBlocksByUserHour[c.userId] ??= {})[h] ??= <int>{};
      clipBlocksByUserHour[c.userId]![h]!.add(block);
    }

    final out = <String, Map<int, int>>{};
    for (final s in slots) {
      final userId = s.userId;
      final byHour = <int, int>{};
      for (int h = 0; h < 24; h++) {
        final scores = focusScoresByUserHour[userId]?[h];
        if (scores != null && scores.isNotEmpty) {
          final avg =
              (scores.reduce((a, b) => a + b) / scores.length).round();
          byHour[h] = avg.clamp(0, 100);
          continue;
        }

        final mins = photoMinutesByUserHour[userId]?[h]?.length ?? 0;
        final blocks = clipBlocksByUserHour[userId]?[h]?.length ?? 0;
        final clipAsMinutes = blocks * 10;
        final active = (mins + clipAsMinutes).clamp(0, 60);
        if (active <= 0) continue;
        final percent = ((active / 60.0) * 100).round();
        byHour[h] = percent.clamp(0, 100);
      }
      out[userId] = byHour;
    }
    return out;
  }

  static Future<int> updateAndGetStreakDays(DateTime downloadedAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const kCount = 'setudy.study_streak.count';
      const kLast = 'setudy.study_streak.last_day_yyyymmdd';

      final today = downloadedAt.toLocal();
      final todayKey = today.year * 10000 + today.month * 100 + today.day;

      final lastKey = prefs.getInt(kLast);
      var count = prefs.getInt(kCount) ?? 0;

      if (lastKey == null) {
        count = 1;
      } else if (lastKey != todayKey) {
        final lastDate = DateTime(
          lastKey ~/ 10000,
          (lastKey % 10000) ~/ 100,
          lastKey % 100,
        );
        final diffDays = today
            .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
            .difference(lastDate.copyWith(
                hour: 0, minute: 0, second: 0, millisecond: 0))
            .inDays;
        count = diffDays == 1 ? (count <= 0 ? 1 : count + 1) : 1;
      }

      await prefs.setInt(kLast, todayKey);
      await prefs.setInt(kCount, count);
      return count;
    } catch (_) {
      return 0;
    }
  }

  static Future<Map<String, Uint8List>> fetchAllBytes(Set<String> urls) async {
    final result = <String, Uint8List>{};
    await Future.wait(
      urls.map((url) async {
        try {
          final uri = Uri.parse(url);
          var res = await http.get(uri);
          if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
            // 캐시 버스터 쿼리가 문제일 때 한 번 더 시도
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

  static Future<Uint8List?> renderGridFrame({
    required List<GridSlotFrame> slots,
    required String hourLabel,
    required int width,
    required int height,
    required int streakDays,
    required bool showStreak,
    bool showHourLabel = true,
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
            14,
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

      final p = slot.focusPercent;
      if (p != null) {
        _drawBottomRightPill(canvas, '집중도 ${p.clamp(0, 100)}%', rect);
      }

      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0x44FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }

    if (showHourLabel) {
      _drawTopHourLabel(canvas, hourLabel, width.toDouble());
    }

    if (showStreak && streakDays >= 2) {
      _drawStreakBadge(canvas, streakDays);
    }

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
    double maxWidth = 200,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          shadows: const [
            Shadow(blurRadius: 4, color: Color(0xAA000000)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
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

  static void _drawBottomRightPill(Canvas canvas, String text, Rect rect) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(blurRadius: 3, color: Color(0xBB000000))],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: rect.width - 16);

    const padX = 8.0;
    const padY = 5.0;
    final pillW = tp.width + padX * 2;
    final pillH = tp.height + padY * 2;
    final x = rect.right - pillW - 8;
    final y = rect.bottom - pillH - 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, pillW, pillH),
        const Radius.circular(999),
      ),
      Paint()..color = const Color(0x66000000),
    );
    tp.paint(canvas, Offset(x + padX, y + padY));
  }

  static void _drawTopHourLabel(Canvas canvas, String label, double width) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          shadows: [Shadow(blurRadius: 6, color: Color(0xAA000000))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    final bgRect = Rect.fromLTWH(
      (width - tp.width) / 2 - 8,
      8,
      tp.width + 16,
      tp.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(8)),
      Paint()..color = const Color(0x88000000),
    );
    tp.paint(canvas, Offset((width - tp.width) / 2, 12));
  }

  static void _drawStreakBadge(Canvas canvas, int days) {
    final text = '🔥 $days일 연속 공부중';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(blurRadius: 6, color: Color(0xAA000000))],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 320);

    const x = 12.0;
    const y = 54.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 8, y - 6, tp.width + 16, tp.height + 12),
        const Radius.circular(12),
      ),
      Paint()..color = const Color(0xAA000000),
    );
    tp.paint(canvas, const Offset(x, y));
  }
}
