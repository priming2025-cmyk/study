/// 집중도 시계열 한 포인트.
class StudyRoomFocusSample {
  final DateTime at;
  final int score;

  const StudyRoomFocusSample({required this.at, required this.score});
}

/// 그래프용 정규화·다운샘플.
abstract final class StudyRoomFocusTimeline {
  static const int minPointsForChart = 3;

  /// 최대 [maxPoints]개로 균등 다운샘플 (오래된 구간 유지).
  static List<int> downsampleScores(List<int> raw, {int maxPoints = 72}) {
    if (raw.isEmpty) return const [];
    if (raw.length <= maxPoints) return List<int>.from(raw);
    final out = <int>[];
    final step = raw.length / maxPoints;
    for (var i = 0; i < maxPoints; i++) {
      final start = (i * step).floor();
      final end = ((i + 1) * step).floor().clamp(start + 1, raw.length);
      var sum = 0;
      for (var j = start; j < end; j++) {
        sum += raw[j];
      }
      out.add((sum / (end - start)).round().clamp(0, 100));
    }
    return out;
  }

  static int averageOf(List<int> scores) {
    if (scores.isEmpty) return 0;
    return (scores.reduce((a, b) => a + b) / scores.length).round().clamp(0, 100);
  }

  /// 분 단위 스냅 → 점수만 (시간순).
  static List<int> scoresFromSnaps(List<StudyRoomFocusSample> snaps) {
    final sorted = List<StudyRoomFocusSample>.from(snaps)
      ..sort((a, b) => a.at.compareTo(b.at));
    return [for (final s in sorted) s.score.clamp(0, 100)];
  }
}
