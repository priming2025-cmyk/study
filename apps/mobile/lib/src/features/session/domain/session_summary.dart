enum ValidationState { ok, uncertain, failed }

class SessionSummary {
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? subject;
  final String? planItemId;
  final int focusedSeconds;
  final int unfocusedSeconds;
  final ValidationState validationState;
  final int pauseCount;
  final int appBackgroundCount;
  final int faceMissingEvents;
  final int multiFaceEvents;

  /// 0~100 평균 집중도 점수 (face_detection_tflite 기반; 웹은 항상 100).
  final int concentrationScore;

  /// 총 눈 깜빡임 횟수.
  final int blinkCount;

  /// 눈 감김이 2초 이상 지속된 이벤트 횟수 (졸음 지표).
  final int drowsyEvents;

  /// 시선 이탈이 3초 이상 지속된 이벤트 횟수.
  final int distractedEvents;

  const SessionSummary({
    required this.startedAt,
    required this.endedAt,
    required this.subject,
    required this.planItemId,
    required this.focusedSeconds,
    required this.unfocusedSeconds,
    required this.validationState,
    required this.pauseCount,
    required this.appBackgroundCount,
    required this.faceMissingEvents,
    required this.multiFaceEvents,
    this.concentrationScore = 100,
    this.blinkCount = 0,
    this.drowsyEvents = 0,
    this.distractedEvents = 0,
  });
}
