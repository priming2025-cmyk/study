import 'attention_signals.dart';
import 'session_summary.dart';

/// 집중 상태 5단계.
enum FocusStatus {
  focused,    // 집중 중 (점수 80~100)
  normal,     // 보통 (점수 50~79)
  distracted, // 시선 이탈 (점수 20~49)
  drowsy,     // 졸음 (점수 0~19)
  away,       // 자리 이탈 (얼굴 없음)
}

extension FocusStatusLabel on FocusStatus {
  String get label => switch (this) {
        FocusStatus.focused => '집중',
        FocusStatus.normal => '보통',
        FocusStatus.distracted => '이탈',
        FocusStatus.drowsy => '졸음',
        FocusStatus.away => '자리이탈',
      };
}

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

  // 확장 지표
  final int blinkCount;       // 총 깜빡임 횟수
  final int drowsyEvents;     // 눈 감김 연속 2초+ 이벤트
  final int distractedEvents; // 시선 이탈 연속 이벤트
  final double scoreSum;      // 집중도 점수 합산 (평균 계산용)
  final int scoreTicks;       // 점수 측정 횟수
  final FocusStatus lastStatus;

  // 졸음·이탈 연속 프레임 카운터 (내부 상태)
  final int _drowsyStreak;    // 연속 눈감김 초
  final int _distractedStreak; // 연속 이탈 초

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
    this.blinkCount = 0,
    this.drowsyEvents = 0,
    this.distractedEvents = 0,
    this.scoreSum = 0,
    this.scoreTicks = 0,
    this.lastStatus = FocusStatus.focused,
    int drowsyStreak = 0,
    int distractedStreak = 0,
  })  : _drowsyStreak = drowsyStreak,
        _distractedStreak = distractedStreak;

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

  /// 0~100 평균 집중도 점수.
  int get averageScore =>
      scoreTicks == 0 ? 100 : (scoreSum / scoreTicks).round().clamp(0, 100);
}

class AttentionScoring {
  /// 신호 1틱(1초)당 집중도 점수 계산.
  ///
  /// 점수 공식:
  ///   100점 기준 → 각 조건 위반 시 차감
  ///   - 얼굴 없음: 0점 고정
  ///   - 눈 감김(졸음): -80
  ///   - 시선 이탈: -50
  ///   - 다중 얼굴: -30
  ///   - 앱 백그라운드: 0점 고정
  static int _computeScore(AttentionSignals s) {
    if (!s.appInForeground) return 0;
    if (!s.facePresent) return 0;
    int score = 100;
    if (s.eyesClosed) score -= 80;
    if (s.headAway) score -= 50;
    if (s.multiFace) score -= 30;
    return score.clamp(0, 100);
  }

  static FocusStatus _statusFromScore(int score, AttentionSignals s) {
    if (!s.facePresent) return FocusStatus.away;
    if (s.eyesClosed) return FocusStatus.drowsy;
    if (score >= 80) return FocusStatus.focused;
    if (score >= 50) return FocusStatus.normal;
    if (score >= 20) return FocusStatus.distracted;
    return FocusStatus.drowsy;
  }

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
        paused: true,
        blinkCount: state.blinkCount,
        drowsyEvents: state.drowsyEvents,
        distractedEvents: state.distractedEvents,
        scoreSum: state.scoreSum,
        scoreTicks: state.scoreTicks,
        lastStatus: state.lastStatus,
        drowsyStreak: state._drowsyStreak,
        distractedStreak: state._distractedStreak,
      );
    }

    final delta = now.difference(state.lastTickAt).inSeconds.clamp(0, 5);
    final score = _computeScore(signals);
    final status = _statusFromScore(score, signals);
    final isFocused = score >= 50 && signals.facePresent;

    final faceMissing = state.faceMissingEvents + (signals.facePresent ? 0 : 1);
    final multiFace = state.multiFaceEvents + (signals.multiFace ? 1 : 0);
    final appBg = state.appBackgroundCount + (signals.appInForeground ? 0 : 1);

    final blinks = state.blinkCount + (signals.blinkFrame ? 1 : 0);

    // 졸음 연속 카운터 (2초 연속이면 이벤트 1회)
    final newDrowsyStreak =
        signals.eyesClosed ? state._drowsyStreak + delta : 0;
    final newDrowsyEvents =
        state.drowsyEvents + (newDrowsyStreak >= 2 && state._drowsyStreak < 2 ? 1 : 0);

    // 시선 이탈 연속 카운터 (3초 연속이면 이벤트 1회)
    final newDistractedStreak =
        signals.headAway ? state._distractedStreak + delta : 0;
    final newDistractedEvents = state.distractedEvents +
        (newDistractedStreak >= 3 && state._distractedStreak < 3 ? 1 : 0);

    return AttentionScoringState(
      startedAt: state.startedAt,
      lastTickAt: now,
      focusedSeconds: state.focusedSeconds + (isFocused ? delta : 0),
      unfocusedSeconds: state.unfocusedSeconds + (!isFocused ? delta : 0),
      pauseCount: state.pauseCount,
      appBackgroundCount: appBg,
      faceMissingEvents: faceMissing,
      multiFaceEvents: multiFace,
      paused: false,
      blinkCount: blinks,
      drowsyEvents: newDrowsyEvents,
      distractedEvents: newDistractedEvents,
      scoreSum: state.scoreSum + score,
      scoreTicks: state.scoreTicks + 1,
      lastStatus: status,
      drowsyStreak: newDrowsyStreak,
      distractedStreak: newDistractedStreak,
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
      blinkCount: state.blinkCount,
      drowsyEvents: state.drowsyEvents,
      distractedEvents: state.distractedEvents,
      scoreSum: state.scoreSum,
      scoreTicks: state.scoreTicks,
      lastStatus: state.lastStatus,
      drowsyStreak: state._drowsyStreak,
      distractedStreak: state._distractedStreak,
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
      blinkCount: state.blinkCount,
      drowsyEvents: state.drowsyEvents,
      distractedEvents: state.distractedEvents,
      scoreSum: state.scoreSum,
      scoreTicks: state.scoreTicks,
      lastStatus: state.lastStatus,
      drowsyStreak: 0,
      distractedStreak: 0,
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
        : (state.multiFaceEvents > 0
            ? ValidationState.uncertain
            : ValidationState.ok);

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
      concentrationScore: state.averageScore,
      blinkCount: state.blinkCount,
      drowsyEvents: state.drowsyEvents,
      distractedEvents: state.distractedEvents,
    );
  }
}
