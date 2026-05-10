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
  });
}

