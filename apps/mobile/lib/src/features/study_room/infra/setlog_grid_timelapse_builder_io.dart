import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import 'setlog_grid_timelapse_builder.dart';
import 'setlog_grid_timelapse_frames.dart';

abstract final class SetlogGridTimelapseBuilderImpl {
  static Future<String?> buildAndSave({required GridBuildInput input}) async {
    if (input.slots.isEmpty || input.allPhotos.isEmpty) return null;

    final prep = await SetlogGridTimelapseFrames.prepare(input);
    if (prep.validMinuteKeys.isEmpty) return null;

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
      final introFrames = SetlogGridTimelapseFrames.introOutroFrameCount(input);
      final titleRgba = await SetlogGridTimelapseFrames.renderTitleFrame(
        date: input.downloadedAt,
        width: input.width,
        height: input.height,
      );
      if (titleRgba != null) {
        for (var i = 0; i < introFrames; i++) {
          await FlutterQuickVideoEncoder.appendVideoFrame(titleRgba);
        }
      }

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
        );
        if (rgba != null) {
          for (var i = 0; i < spec.repeat; i++) {
            await FlutterQuickVideoEncoder.appendVideoFrame(rgba);
          }
        }
      }

      final outroRgba = await SetlogGridTimelapseFrames.renderOutroFrame(
        width: input.width,
        height: input.height,
      );
      if (outroRgba != null) {
        for (var i = 0; i < introFrames; i++) {
          await FlutterQuickVideoEncoder.appendVideoFrame(outroRgba);
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
