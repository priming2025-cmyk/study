import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import '../../session/infra/attention_camera_service.dart';
import '../../session/infra/session_camera_cache.dart';
import '../../session/infra/web_camera.dart';
import '../domain/study_video_clip_config.dart';

/// 2초 영상 촬영 전 카메라·웹 스트림 준비 (Android·iOS·Web 공통).
abstract final class StudyRoomPublicVideoCapture {
  static Future<bool> ensureCameraReady({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (kIsWeb) {
      WebSharedCamera.instance.openFromUserGesture();
      await WebSharedCamera.instance.acquire();
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (WebSharedCamera.instance.isStreamReady) return true;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      debugPrint(
        '[StudyRoomPublicVideoCapture] web stream not ready: '
        '${WebSharedCamera.instance.lastOpenError}',
      );
      return false;
    }

    if (AttentionCameraService.instance.hasActiveCamera) return true;

    try {
      final cam = await SessionCameraCache.getFrontOrDefault();
      if (cam == null) {
        debugPrint('[StudyRoomPublicVideoCapture] no front camera');
        return false;
      }
      await AttentionCameraService.instance.acquire(
        camera: cam,
        appInForeground: () => true,
      );
    } catch (e, st) {
      debugPrint('[StudyRoomPublicVideoCapture] acquire: $e\n$st');
      return false;
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (AttentionCameraService.instance.hasActiveCamera) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  static bool get isReady {
    if (kIsWeb) return WebSharedCamera.instance.isStreamReady;
    return AttentionCameraService.instance.hasActiveCamera;
  }

  static int get maxUploadBytes => StudyVideoClipConfig.maxUploadBytes;
}
