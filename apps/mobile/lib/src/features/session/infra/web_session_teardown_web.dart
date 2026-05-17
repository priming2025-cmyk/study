import 'web_camera.dart';
import 'web_face_detector_holder.dart';

Future<void> teardownWebSessionMedia() async {
  WebSharedCamera.instance.forceRelease();
  await WebFaceDetectorHolder.instance.disposeAll();
}
