import 'session_media_lifecycle.dart';

/// 공부 세션 종료 시 카메라를 완전히 끕니다 (재시작 시 정지 화면 방지).
Future<void> teardownWebSessionMedia() async {
  await teardownSharedCameraMedia();
}
