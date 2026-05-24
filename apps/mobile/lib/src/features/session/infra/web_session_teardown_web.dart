import 'web_camera.dart';
import 'web_face_detector_holder.dart';

/// 공부 세션 종료 시 카메라·분석 엔진을 **완전히** 끄지 않고 잠시 유지합니다.
/// (연속 공부 시 브라우저 재허용·정지 화면 방지)
Future<void> teardownWebSessionMedia() async {
  WebSharedCamera.instance.release();
}

/// 앱 종료·로그아웃 등에서만 호출.
Future<void> forceTeardownWebSessionMedia() async {
  WebSharedCamera.instance.forceRelease();
  await WebFaceDetectorHolder.instance.disposeAll();
}
