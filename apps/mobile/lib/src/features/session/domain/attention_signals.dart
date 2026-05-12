/// 카메라 프레임 1장에서 추출한 얼굴 신호 모음.
///
/// - 웹: [FaceAttentionSensor] 웹 구현이 `takePicture` JPEG로
///   [FaceDetector.detectFaces] 로 채움(로컬만, 전송 없음).
/// - 앱(face_attention_sensor_io.dart): face_detection_tflite 실시간 스트림 추출.
class AttentionSignals {
  final bool facePresent;
  final bool multiFace;
  final bool appInForeground;

  /// 왼쪽·오른쪽 눈 EAR (Eye Aspect Ratio, 0.0~0.4).
  /// 0.2 미만이면 눈 감김으로 판정.
  final double earLeft;
  final double earRight;

  /// 머리 기울기 각도(도). 정면 기준:
  /// - [headYaw]  : 좌우(-왼쪽 / +오른쪽). |yaw| > 25°면 시선 이탈.
  /// - [headPitch]: 상하(-아래 / +위). |pitch| > 20°면 시선 이탈.
  final double headYaw;
  final double headPitch;

  /// 이번 프레임에서 깜빡임이 발생했는지 (EAR < 0.2 인 프레임).
  final bool blinkFrame;

  const AttentionSignals({
    required this.facePresent,
    required this.multiFace,
    required this.appInForeground,
    this.earLeft = 0.3,
    this.earRight = 0.3,
    this.headYaw = 0.0,
    this.headPitch = 0.0,
    this.blinkFrame = false,
  });

  /// 두 눈이 모두 0.2 미만 → 눈 감김(졸음) 판정.
  bool get eyesClosed => earLeft < 0.2 && earRight < 0.2;

  /// 머리가 정면에서 벗어난 경우.
  bool get headAway => headYaw.abs() > 25 || headPitch.abs() > 20;
}
