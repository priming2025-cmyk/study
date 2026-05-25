import 'session_media_lifecycle.dart';

/// 공부 세션 종료 시 카메라 참조만 해제합니다 (스트림은 잠시 유지 → 재허용 감소).
Future<void> teardownWebSessionMedia() async {
  await releaseSharedCameraMedia();
}
