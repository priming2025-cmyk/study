import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/study_room_photo_snap_row.dart';
import '../domain/study_room_video_clip_row.dart';
import 'setlog_grid_timelapse_builder.dart';

// ──────────────────────────────────────────────────────────────────────────────
// 내부 헬퍼 타입
// ──────────────────────────────────────────────────────────────────────────────

class _SlotFrame {
  final String? displayName;
  final String? statusText;
  final Uint8List? imageBytes; // null → "자리비움"
  final int? activityPercent; // 0..100

  const _SlotFrame({
    this.displayName,
    this.statusText,
    this.imageBytes,
    this.activityPercent,
  });
}

// ──────────────────────────────────────────────────────────────────────────────

abstract final class SetlogGridTimelapseBuilderImpl {
  static Future<String?> buildAndSave({required GridBuildInput input}) async {
    if (input.allPhotos.isEmpty && input.allClips.isEmpty) return null;
    if (input.slots.isEmpty) return null;

    // 1. 분 단위 조회 맵: userId → {minuteOfDay → photoUrl}
    final photoMap = _buildPhotoMap(input.allPhotos);
    // userId → {minuteOfDay → posterUrl} (10분 단위)
    final clipMap = _buildClipMap(input.allClips);

    // 2. 데이터가 있는 시간대(hour) 수집
    final validHours = _getValidHours(input.allPhotos, input.allClips);
    if (validHours.isEmpty) return null;

    // 2.5 바이럴 #2: 연속 공부(스트릭) 배지 (로컬)
    final streakDays = await _updateAndGetStreakDays(input.downloadedAt);

    // 2.6 바이럴 #4: 멤버별 활동률(%) 계산 (시간별)
    final activityByUserHour = _buildActivityByUserHour(
      slots: input.slots,
      photos: input.allPhotos,
      clips: input.allClips,
    );

    // 3. 사용할 모든 URL 수집 → 병렬 다운로드
    final allUrls = <String>{};
    for (final um in photoMap.values) allUrls.addAll(um.values);
    for (final um in clipMap.values) allUrls.addAll(um.values);
    final bytesCache = await _fetchAllBytes(allUrls);

    // 4. 인코더 셋업
    final dir = await getTemporaryDirectory();
    final tag = _nowTag(input.downloadedAt);
    final outPath = '${dir.path}/setudy_celolog_$tag.mp4';

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
      var globalFrameIndex = 0;
      for (final hour in validHours) {
        final hourLabel =
            '${hour.toString().padLeft(2, '0')}:00';

        for (int minute = 0; minute < 60; minute++) {
          final isFirstFrame = globalFrameIndex == 0;
          final minuteKey = hour * 60 + minute;
          // 10분 단위 클립 포스터 키
          final clipKey = hour * 60 + (minute ~/ 10) * 10;

          final frames = <_SlotFrame>[];
          for (final slot in input.slots) {
            // 사진 우선, 없으면 클립 포스터, 없으면 carry-forward
            final photoUrl = photoMap[slot.userId]?[minuteKey] ??
                _carryForward(photoMap[slot.userId], minuteKey);
            final clipUrl = clipMap[slot.userId]?[clipKey];
            final url = photoUrl ?? clipUrl;

            // 사진의 status_text 활용 (해당 분의 실제 상태)
            final snap = url != null
                ? _findSnap(input.allPhotos, slot.userId, minuteKey)
                : null;
            final statusText =
                snap?.statusText ?? slot.statusText;

            frames.add(_SlotFrame(
              displayName: slot.displayName,
              statusText: statusText,
              imageBytes: url != null ? bytesCache[url] : null,
              activityPercent: activityByUserHour[slot.userId]?[hour],
            ));
          }

          final rgba = await _renderGridFrame(
            slots: frames,
            hourLabel: hourLabel,
            width: input.width,
            height: input.height,
            streakDays: streakDays,
            showStreak: isFirstFrame,
          );
          if (rgba != null) {
            await FlutterQuickVideoEncoder.appendVideoFrame(rgba);
          }
          globalFrameIndex++;
        }
      }
    } catch (e, st) {
      debugPrint('[GridTimelapse] 인코딩 오류: $e\n$st');
      try {
        await FlutterQuickVideoEncoder.finish();
      } catch (_) {}
      return null;
    }

    await FlutterQuickVideoEncoder.finish();

    final file = File(outPath);
    if (!await file.exists()) return null;

    // 5. 갤러리에 저장
    try {
      await Gal.putVideo(outPath, album: 'Setudy');
    } catch (e) {
      debugPrint('[GridTimelapse] 갤러리 저장 실패: $e');
    }
    return outPath;
  }

  // ── 데이터 조회 헬퍼 ────────────────────────────────────────────────────────

  static Map<String, Map<int, String>> _buildPhotoMap(
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

  static Map<String, Map<int, String>> _buildClipMap(
    List<StudyRoomVideoClipRow> clips,
  ) {
    final map = <String, Map<int, String>>{};
    for (final c in clips) {
      final url = c.posterUrl;
      if (url == null || url.isEmpty) continue;
      final local = c.recordedAt.toLocal();
      final key = local.hour * 60 + local.minute;
      (map[c.userId] ??= {})[key] = url;
    }
    return map;
  }

  /// 한 사용자의 minuteKey 이전 가장 최근 사진 URL (같은 시간 내)
  static String? _carryForward(Map<int, String>? userMap, int minuteKey) {
    if (userMap == null) return null;
    final hour = minuteKey ~/ 60;
    String? last;
    for (int m = hour * 60; m <= minuteKey; m++) {
      final url = userMap[m];
      if (url != null) last = url;
    }
    return last;
  }

  static StudyRoomPhotoSnapRow? _findSnap(
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

  static List<int> _getValidHours(
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

  static Map<String, Map<int, int>> _buildActivityByUserHour({
    required List<GridMemberSlot> slots,
    required List<StudyRoomPhotoSnapRow> photos,
    required List<StudyRoomVideoClipRow> clips,
  }) {
    // 활동률 정의: 해당 시간대(1시간)에서 “콘텐츠가 존재한 분(minute)” 비율 기반.
    // - photos: 실제 분 단위로 1분=1장이라 가장 정확
    // - clips: 10분=1개 → 해당 시간에 clip이 있으면 그 10분 구간은 활동으로 간주
    final photoMinutesByUserHour = <String, Map<int, Set<int>>>{};
    for (final p in photos) {
      final l = p.recordedAt.toLocal();
      final h = l.hour;
      final m = l.minute;
      (photoMinutesByUserHour[p.userId] ??= {})[h] ??= <int>{};
      photoMinutesByUserHour[p.userId]![h]!.add(m);
    }

    final clipBlocksByUserHour = <String, Map<int, Set<int>>>{};
    for (final c in clips) {
      if (c.posterUrl?.isNotEmpty != true) continue;
      final l = c.recordedAt.toLocal();
      final h = l.hour;
      final block = (l.minute ~/ 10) * 10; // 0,10,20...
      (clipBlocksByUserHour[c.userId] ??= {})[h] ??= <int>{};
      clipBlocksByUserHour[c.userId]![h]!.add(block);
    }

    final out = <String, Map<int, int>>{};
    for (final s in slots) {
      final userId = s.userId;
      final byHour = <int, int>{};
      for (int h = 0; h < 24; h++) {
        final mins = photoMinutesByUserHour[userId]?[h]?.length ?? 0;
        final blocks = clipBlocksByUserHour[userId]?[h]?.length ?? 0;
        // clip 1개는 10분 활동으로 환산
        final clipAsMinutes = blocks * 10;
        final active = (mins + clipAsMinutes).clamp(0, 60);
        final percent = ((active / 60.0) * 100).round();
        if (active > 0) byHour[h] = percent;
      }
      out[userId] = byHour;
    }
    return out;
  }

  static Future<int> _updateAndGetStreakDays(DateTime downloadedAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const kCount = 'setudy.study_streak.count';
      const kLast = 'setudy.study_streak.last_day_yyyymmdd';

      final today = downloadedAt.toLocal();
      final todayKey =
          today.year * 10000 + today.month * 100 + today.day; // yyyymmdd

      final lastKey = prefs.getInt(kLast);
      var count = prefs.getInt(kCount) ?? 0;

      if (lastKey == null) {
        count = 1;
      } else if (lastKey == todayKey) {
        // same day: no change
      } else {
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
        if (diffDays == 1) {
          count = (count <= 0 ? 1 : count + 1);
        } else {
          count = 1;
        }
      }

      await prefs.setInt(kLast, todayKey);
      await prefs.setInt(kCount, count);
      return count;
    } catch (_) {
      return 0;
    }
  }

  static Future<Map<String, Uint8List>> _fetchAllBytes(
    Set<String> urls,
  ) async {
    final result = <String, Uint8List>{};
    await Future.wait(
      urls.map((url) async {
        try {
          final res = await http.get(Uri.parse(url));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            result[url] = res.bodyBytes;
          }
        } catch (_) {}
      }),
      eagerError: false,
    );
    return result;
  }

  // ── 프레임 렌더링 ────────────────────────────────────────────────────────────

  /// 멤버 수에 따른 그리드 레이아웃 Rect 목록
  static List<Rect> _layoutRects(int n, double w, double h) {
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
      // 나(idx 0) 상단 전체, 나머지 2x2
      return [
        Rect.fromLTWH(0, 0, w, h / 2),
        Rect.fromLTWH(0, h / 2, w / 2, h / 4),
        Rect.fromLTWH(w / 2, h / 2, w / 2, h / 4),
        Rect.fromLTWH(0, 3 * h / 4, w / 2, h / 4),
        Rect.fromLTWH(w / 2, 3 * h / 4, w / 2, h / 4),
      ];
    }
    // 6+ : 2열
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

  static Future<Uint8List?> _renderGridFrame({
    required List<_SlotFrame> slots,
    required String hourLabel,
    required int width,
    required int height,
    required int streakDays,
    required bool showStreak,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    // 배경
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF0D0D1A),
    );

    final rects = _layoutRects(slots.length, width.toDouble(), height.toDouble());

    for (int i = 0; i < slots.length; i++) {
      if (i >= rects.length) break;
      final rect = rects[i];
      final slot = slots[i];

      if (slot.imageBytes != null) {
        // 이미지 디코딩 & 그리기
        try {
          final codec = await ui.instantiateImageCodec(
            slot.imageBytes!,
            targetWidth: rect.width.round(),
            targetHeight: rect.height.round(),
          );
          final fi = await codec.getNextFrame();
          final img = fi.image;
          final src = Rect.fromLTWH(
            0, 0, img.width.toDouble(), img.height.toDouble(),
          );
          canvas.drawImageRect(img, src, rect, Paint());
          img.dispose();

          // 하단 그라디언트 (텍스트 가독성)
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

        // 상태텍스트 오버레이 (중앙, 반투명 흰색)
        if (slot.statusText?.trim().isNotEmpty == true) {
          _drawCenteredLabel(
            canvas,
            slot.statusText!.trim(),
            Offset(rect.center.dx, rect.center.dy),
            14,
            maxWidth: rect.width - 16,
          );
        }
      } else {
        _drawAbsent(canvas, rect, slot.displayName);
      }

      // 이름 레이블 (좌상단)
      final name = slot.displayName?.trim();
      if (name != null && name.isNotEmpty) {
        _drawCornerLabel(canvas, name, Offset(rect.left + 8, rect.top + 8));
      }

      // 활동률(%) 레이블 (우하단)
      final p = slot.activityPercent;
      if (p != null) {
        _drawBottomRightPill(
          canvas,
          '활동 ${p.clamp(0, 100)}%',
          rect,
        );
      }

      // 셀 구분선
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0x44FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }

    // 시간 레이블 (중앙 상단, 내 상태와 같은 스타일)
    _drawTopHourLabel(canvas, hourLabel, width.toDouble());

    // 바이럴 #2: 스트릭 배지 (첫 프레임 1회)
    if (showStreak && streakDays >= 2) {
      _drawStreakBadge(canvas, streakDays);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  // ── 텍스트 그리기 유틸 ───────────────────────────────────────────────────────

  static void _drawAbsent(Canvas canvas, Rect rect, String? name) {
    canvas.drawRect(rect, Paint()..color = const Color(0xFF1A1A2E));
    _drawCenteredLabel(canvas, '자리비움', rect.center, 16,
        color: const Color(0xFF555577));
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

    final padX = 8.0;
    final padY = 5.0;
    final pillW = tp.width + padX * 2;
    final pillH = tp.height + padY * 2;
    final x = rect.right - pillW - 8;
    final y = rect.bottom - pillH - 8;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, pillW, pillH),
      const Radius.circular(999),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0x66000000));
    tp.paint(canvas, Offset(x + padX, y + padY));
  }

  /// 중앙 상단 시간 레이블 (내 상태 텍스트와 동일 스타일)
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
    // 배경 반투명
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
    final text = '🔥 ${days}일 연속 공부중';
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

    final x = 12.0;
    final y = 54.0; // 시간 레이블과 겹치지 않게
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - 8, y - 6, tp.width + 16, tp.height + 12),
      const Radius.circular(12),
    );
    canvas.drawRRect(bg, Paint()..color = const Color(0xAA000000));
    tp.paint(canvas, Offset(x, y));
  }

  static String _nowTag(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}${l.month.toString().padLeft(2, '0')}'
        '${l.day.toString().padLeft(2, '0')}_'
        '${l.hour.toString().padLeft(2, '0')}'
        '${l.minute.toString().padLeft(2, '0')}';
  }
}

