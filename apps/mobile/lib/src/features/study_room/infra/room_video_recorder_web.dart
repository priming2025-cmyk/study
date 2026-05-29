import 'package:flutter/foundation.dart';

import '../../session/infra/web_shared_camera.dart';
import '../domain/study_video_clip_config.dart';
import '../domain/study_video_clip_result.dart';

/// 웹: [WebSharedCamera] 스트림에서 VP8 WebM 녹화 (서버·24h·셀로그).
class RoomVideoRecorder {
  Future<void> initialize() async {}

  Future<StudyVideoClipResult?> captureCompressedClip() async {
    try {
      await WebSharedCamera.instance.acquire();
      for (var i = 0; i < 60; i++) {
        if (WebSharedCamera.instance.isStreamReady) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!WebSharedCamera.instance.isStreamReady) {
        debugPrint(
          '[RoomVideoRecorder/web] camera not ready: '
          '${WebSharedCamera.instance.lastOpenError}',
        );
        return null;
      }

      final bytes = await WebSharedCamera.instance.recordWebmClip();
      if (bytes == null || bytes.isEmpty) return null;
      if (bytes.length > StudyVideoClipConfig.maxUploadBytes) {
        // config와 Supabase bucket(0040) 한도 일치
        debugPrint(
          '[RoomVideoRecorder/web] clip too large (${bytes.length} bytes), skip',
        );
        return null;
      }
      final poster = await WebSharedCamera.instance.captureJpeg(
        maxDim: StudyVideoClipConfig.posterMaxDim.toDouble(),
        quality: StudyVideoClipConfig.posterJpegQuality / 100,
      );
      return StudyVideoClipResult(
        videoBytes: bytes,
        mimeType: 'video/webm',
        fileExtension: 'webm',
        durationMs: StudyVideoClipConfig.slotDurationMs,
        posterJpeg: poster,
      );
    } catch (e, st) {
      debugPrint('[RoomVideoRecorder/web] $e\n$st');
      return null;
    }
  }

  Future<void> dispose() async {}
}
