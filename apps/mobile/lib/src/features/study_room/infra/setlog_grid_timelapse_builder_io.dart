import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/study_room_photo_snap_row.dart';
import '../domain/study_room_video_clip_row.dart';
import 'setlog_grid_timelapse_builder.dart';
import 'setlog_grid_timelapse_frames.dart';

abstract final class SetlogGridTimelapseBuilderImpl {
  static bool _hasRenderableMedia(
    List<StudyRoomPhotoSnapRow> photos,
    List<StudyRoomVideoClipRow> clips,
  ) {
    if (photos.isNotEmpty) return true;
    return clips.any((c) => c.posterUrl?.trim().isNotEmpty == true);
  }

  static Future<String?> buildAndSave({required GridBuildInput input}) async {
    if (input.slots.isEmpty) return null;
    if (!_hasRenderableMedia(input.allPhotos, input.allClips)) return null;

    final prep = await SetlogGridTimelapseFrames.prepare(input);
    if (prep.validHours.isEmpty) return null;

    final bytesCache =
        await SetlogGridTimelapseFrames.fetchAllBytes(SetlogGridTimelapseFrames.collectUrls(prep));

    final dir = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/setudy_celolog_${SetlogGridTimelapseFrames.nowTag(input.downloadedAt)}.mp4';

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
      for (final hour in prep.validHours) {
        final hourLabel = '${hour.toString().padLeft(2, '0')}:00';

        for (int minute = 0; minute < 60; minute++) {
          final slots = SetlogGridTimelapseFrames.buildSlotFrames(
            input: input,
            prep: prep,
            bytesCache: bytesCache,
            hour: hour,
            minute: minute,
          );

          final rgba = await SetlogGridTimelapseFrames.renderGridFrame(
            slots: slots,
            hourLabel: hourLabel,
            width: input.width,
            height: input.height,
            streakDays: prep.streakDays,
            showStreak: globalFrameIndex == 0,
            showHourLabel: minute == 0,
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

    try {
      await Gal.putVideo(outPath, album: 'Setudy');
    } catch (e) {
      debugPrint('[GridTimelapse] 갤러리 저장 실패: $e');
    }
    return outPath;
  }
}
