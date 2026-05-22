/// 계획 반복 설정 (로컬 반복 생성용).
enum PlanRepeatUnit { none, day, week }

class PlanRepeatConfig {
  final PlanRepeatUnit unit;
  final int interval; // N일 또는 N주
  final Set<int> weekdays; // 1=월 … 7=일 (주 반복 시)

  const PlanRepeatConfig({
    this.unit = PlanRepeatUnit.none,
    this.interval = 1,
    this.weekdays = const {1, 2, 3, 4, 5},
  });

  bool get enabled => unit != PlanRepeatUnit.none;

  /// [anchor] 날짜부터 반복 적용할 날짜 목록 (최대 [maxOccurrences]).
  List<DateTime> occurrenceDates(DateTime anchor, {int maxOccurrences = 14}) {
    if (!enabled) return [DateTime(anchor.year, anchor.month, anchor.day)];

    final dates = <DateTime>[];
    final start = DateTime(anchor.year, anchor.month, anchor.day);

    if (unit == PlanRepeatUnit.day) {
      for (var i = 0; i < maxOccurrences; i++) {
        dates.add(start.add(Duration(days: i * interval)));
      }
      return dates;
    }

    // 주 단위: anchor 주부터 interval 주마다 선택 요일
    var weekStart = start.subtract(Duration(days: start.weekday - 1));
    while (dates.length < maxOccurrences) {
      for (final wd in weekdays) {
        final d = weekStart.add(Duration(days: wd - 1));
        if (!d.isBefore(start)) dates.add(d);
        if (dates.length >= maxOccurrences) break;
      }
      weekStart = weekStart.add(Duration(days: 7 * interval));
      if (weekStart.isAfter(start.add(const Duration(days: 365)))) break;
    }
    return dates.take(maxOccurrences).toList();
  }
}
