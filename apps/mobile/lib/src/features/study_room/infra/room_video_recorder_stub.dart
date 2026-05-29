import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

import '../../session/infra/attention_camera_service.dart';
import '../domain/study_video_clip_config.dart';
import '../domain/study_video_clip_result.dart';

/// iOS·Android: 단일 카메라에서 2.5초 녹화 → [VideoCompress]로 480p급 H.264 MP4.
class RoomVideoRecorder {
  Future<void> initialize() async {}

  Future<StudyVideoClipResult?> captureCompressedClip() async {
    final path = await AttentionCameraService.instance.captureStudyClipPath();
    if (path == null || path.isEmpty) return null;

    try {
      final info = await VideoCompress.compressVideo(
        path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: true,
        includeAudio: false,
        frameRate: 12,
      );
      final out = info?.file?.path;
      if (out == null) return null;

      final file = File(out);
      if (!await file.exists()) return null;
      var bytes = await file.readAsBytes();
      if (bytes.length > StudyVideoClipConfig.maxUploadBytes) {
        final retry = await VideoCompress.compressVideo(
          out,
          quality: VideoQuality.Res640x480Quality,
          deleteOrigin: true,
          includeAudio: false,
          frameRate: 10,
        );
        final retryPath = retry?.file?.path;
        if (retryPath != null) {
          bytes = await File(retryPath).readAsBytes();
          try {
            await File(retryPath).delete();
          } catch (_) {}
        }
      }

      Uint8List? poster;
      try {
        final thumb = await VideoCompress.getFileThumbnail(
          out,
          quality: StudyVideoClipConfig.posterJpegQuality,
          position: 0,
        );
        if (await thumb.exists()) {
          poster = await thumb.readAsBytes();
        }
      } catch (e) {
        debugPrint('[RoomVideoRecorder] poster: $e');
      }

      try {
        await file.delete();
      } catch (_) {}

      if (bytes.isEmpty) return null;
      return StudyVideoClipResult(
        videoBytes: bytes,
        mimeType: 'video/mp4',
        fileExtension: 'mp4',
        durationMs: StudyVideoClipConfig.slotDurationMs,
        posterJpeg: poster,
      );
    } catch (e, st) {
      debugPrint('[RoomVideoRecorder] compress: $e\n$st');
      try {
        final raw = File(path);
        if (await raw.exists()) {
          final bytes = await raw.readAsBytes();
          if (bytes.isNotEmpty &&
              bytes.length <= StudyVideoClipConfig.maxUploadBytes) {
            await raw.delete();
            return StudyVideoClipResult(
              videoBytes: bytes,
              mimeType: 'video/mp4',
              fileExtension: 'mp4',
              durationMs: StudyVideoClipConfig.slotDurationMs,
            );
          }
        }
        await File(path).delete();
      } catch (_) {}
      return null;
    }
  }

  Future<void> dispose() async {
    await VideoCompress.deleteAllCache();
  }
}
