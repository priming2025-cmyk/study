/// 계획 반복 설정 (로컬 반복 생성용).
enum PlanRepeatUnit { none, day, week }

class PlanRepeatConfig {
  final PlanRepeatUnit unit;
  final int interval; // N일 또는 N주
  final Set<int> weekdays; // 1=월 … 7=일 (주 반복 시)
  final DateTime? startDate; // inclusive, calendar date
  final DateTime? endDate; // inclusive, calendar date

  const PlanRepeatConfig({
    this.unit = PlanRepeatUnit.none,
    this.interval = 1,
    this.weekdays = const {1, 2, 3, 4, 5},
    this.startDate,
    this.endDate,
  });

  bool get enabled => unit != PlanRepeatUnit.none;

  /// [anchor] 날짜부터 반복 적용할 날짜 목록 (최대 [maxOccurrences]).
  List<DateTime> occurrenceDates(DateTime anchor, {int maxOccurrences = 14}) {
    if (!enabled) return [DateTime(anchor.year, anchor.month, anchor.day)];

    final dates = <DateTime>[];
    final anchorDay = DateTime(anchor.year, anchor.month, anchor.day);
    final start = startDate != null
        ? DateTime(startDate!.year, startDate!.month, startDate!.day)
        : anchorDay;
    final end = endDate != null
        ? DateTime(endDate!.year, endDate!.month, endDate!.day)
        : start.add(const Duration(days: 30));

    if (unit == PlanRepeatUnit.day) {
      for (var i = 0; dates.length < maxOccurrences; i++) {
        final d = start.add(Duration(days: i * interval));
        if (d.isAfter(end)) break;
        if (!d.isBefore(anchorDay)) dates.add(d);
      }
      return dates;
    }

    // 주 단위: start 주부터 interval 주마다 선택 요일
    var weekStart = start.subtract(Duration(days: start.weekday - 1));
    while (dates.length < maxOccurrences) {
      for (final wd in weekdays) {
        final d = weekStart.add(Duration(days: wd - 1));
        if (d.isAfter(end)) break;
        if (!d.isBefore(anchorDay) && !d.isBefore(start)) dates.add(d);
        if (dates.length >= maxOccurrences) break;
      }
      weekStart = weekStart.add(Duration(days: 7 * interval));
      if (weekStart.isAfter(end.add(const Duration(days: 7)))) break;
    }
    return dates.take(maxOccurrences).toList();
  }
}
