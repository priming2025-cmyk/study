import 'attention_signals.dart';
import 'session_summary.dart';

class AttentionScoringState {
  final DateTime startedAt;
  final DateTime lastTickAt;
  final int focusedSeconds;
  final int unfocusedSeconds;
  final int pauseCount;
  final int appBackgroundCount;
  final int faceMissingEvents;
  final int multiFaceEvents;
  final bool paused;

  const AttentionScoringState({
    required this.startedAt,
    required this.lastTickAt,
    required this.focusedSeconds,
    required this.unfocusedSeconds,
    required this.pauseCount,
    required this.appBackgroundCount,
    required this.faceMissingEvents,
    required this.multiFaceEvents,
    required this.paused,
  });

  factory AttentionScoringState.started(DateTime at) {
    return AttentionScoringState(
      startedAt: at,
      lastTickAt: at,
      focusedSeconds: 0,
      unfocusedSeconds: 0,
      pauseCount: 0,
      appBackgroundCount: 0,
      faceMissingEvents: 0,
      multiFaceEvents: 0,
      paused: false,
    );
  }
}

class AttentionScoring {
  // MVP rule: if face present, single face, and app foreground => focused
  // otherwise unfocused. No ML weighting in MVP.
  static AttentionScoringState tick({
    required AttentionScoringState state,
    required DateTime now,
    required AttentionSignals signals,
  }) {
    if (state.paused) {
      return AttentionScoringState(
        startedAt: state.startedAt,
        lastTickAt: now,
        focusedSeconds: state.focusedSeconds,
        unfocusedSeconds: state.unfocusedSeconds,
        pauseCount: state.pauseCount,
        appBackgroundCount: state.appBackgroundCount,
        faceMissingEvents: state.faceMissingEvents,
        multiFaceEvents: state.multiFaceEvents,
        paused: state.paused,
      );
    }

    final deltaSeconds =
        now.difference(state.lastTickAt).inSeconds.clamp(0, 5);
    final focusedNow =
        signals.appInForeground && signals.facePresent && !signals.multiFace;

    final faceMissingEvents =
        state.faceMissingEvents + (signals.facePresent ? 0 : 1);
    final multiFaceEvents = state.multiFaceEvents + (signals.multiFace ? 1 : 0);
    final appBackgroundCount =
        state.appBackgroundCount + (signals.appInForeground ? 0 : 1);

    return AttentionScoringState(
      startedAt: state.startedAt,
      lastTickAt: now,
      focusedSeconds:
          state.focusedSeconds + (focusedNow ? deltaSeconds : 0),
      unfocusedSeconds:
          state.unfocusedSeconds + (!focusedNow ? deltaSeconds : 0),
      pauseCount: state.pauseCount,
      appBackgroundCount: appBackgroundCount,
      faceMissingEvents: faceMissingEvents,
      multiFaceEvents: multiFaceEvents,
      paused: state.paused,
    );
  }

  static AttentionScoringState pause(AttentionScoringState state, DateTime now) {
    return AttentionScoringState(
      startedAt: state.startedAt,
      lastTickAt: now,
      focusedSeconds: state.focusedSeconds,
      unfocusedSeconds: state.unfocusedSeconds,
      pauseCount: state.pauseCount + 1,
      appBackgroundCount: state.appBackgroundCount,
      faceMissingEvents: state.faceMissingEvents,
      multiFaceEvents: state.multiFaceEvents,
      paused: true,
    );
  }

  static AttentionScoringState resume(AttentionScoringState state, DateTime now) {
    return AttentionScoringState(
      startedAt: state.startedAt,
      lastTickAt: now,
      focusedSeconds: state.focusedSeconds,
      unfocusedSeconds: state.unfocusedSeconds,
      pauseCount: state.pauseCount,
      appBackgroundCount: state.appBackgroundCount,
      faceMissingEvents: state.faceMissingEvents,
      multiFaceEvents: state.multiFaceEvents,
      paused: false,
    );
  }

  static SessionSummary finalize(
    AttentionScoringState state,
    DateTime endedAt, {
    required String? subject,
    required String? planItemId,
  }) {
    final total = state.focusedSeconds + state.unfocusedSeconds;
    final validationState = total <= 0
        ? ValidationState.failed
        : (state.multiFaceEvents > 0 ? ValidationState.uncertain : ValidationState.ok);

    return SessionSummary(
      startedAt: state.startedAt,
      endedAt: endedAt,
      subject: subject,
      planItemId: planItemId,
      focusedSeconds: state.focusedSeconds,
      unfocusedSeconds: state.unfocusedSeconds,
      validationState: validationState,
      pauseCount: state.pauseCount,
      appBackgroundCount: state.appBackgroundCount,
      faceMissingEvents: state.faceMissingEvents,
      multiFaceEvents: state.multiFaceEvents,
    );
  }
}

