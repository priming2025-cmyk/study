/// 로컬 자정 기준 하루 집중 시간(초).
class DailyFocusStat {
  final DateTime dayLocal;
  final int focusedSeconds;

  const DailyFocusStat({
    required this.dayLocal,
    required this.focusedSeconds,
  });
}
