import '../../data/plan_models.dart';

/// 현재 시각에서 가장 가까운 5분 단위 (당일 분, 05:00~23:55).
int nearestFiveMinuteOfDay(DateTime time) {
  final total = time.hour * 60 + time.minute;
  return ((total / 5).round() * 5).clamp(5 * 60, 23 * 60 + 55);
}

/// 새 계획 시작시간: 기존 계획이 있으면 마지막 종료 시각, 없으면 현재 시각 기준.
int suggestPlanStartMinutes(List<PlanItem> items, DateTime now) {
  if (items.isEmpty) return nearestFiveMinuteOfDay(now);

  var latestEnd = 0;
  for (final item in items) {
    final startAt = item.scheduledStartAt?.toLocal();
    if (startAt == null) continue;
    final startMin = startAt.hour * 60 + startAt.minute;
    final endMin = startMin + (item.targetSeconds / 60).round();
    if (endMin > latestEnd) latestEnd = endMin;
  }

  if (latestEnd == 0) return nearestFiveMinuteOfDay(now);
  return ((latestEnd / 5).round() * 5).clamp(5 * 60, 23 * 60 + 55);
}

/// 직전 계획과 같은 계획시간(분)을 제안.
int? suggestPlanDurationMinutes(List<PlanItem> items) {
  if (items.isEmpty) return null;

  PlanItem? last;
  var latestEnd = 0;
  for (final item in items) {
    final startAt = item.scheduledStartAt?.toLocal();
    if (startAt == null) continue;
    final startMin = startAt.hour * 60 + startAt.minute;
    final endMin = startMin + (item.targetSeconds / 60).round();
    if (endMin >= latestEnd) {
      latestEnd = endMin;
      last = item;
    }
  }

  if (last == null) return null;
  return (last.targetSeconds / 60).round().clamp(5, 240);
}

/// 계획·공부 화면 공통 시간/과목 표시 유틸.
String formatPlanMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0 && m > 0) return '${h}h${m}m';
  if (h > 0) return '${h}h';
  return '${m}m';
}

String formatPlanSeconds(int seconds) => formatPlanMinutes((seconds / 60).round());

/// 계획된 시작~종료 (예: 09:00~09:50).
String formatPlanTimeRange(PlanItem item) {
  final start = item.scheduledStartAt?.toLocal();
  if (start == null && item.targetSeconds <= 0) return '시간 미정';
  if (start == null) {
    return item.targetSeconds > 0
        ? '계획 ${formatPlanSeconds(item.targetSeconds)}'
        : '시간 미정';
  }
  if (item.targetSeconds <= 0) {
    return '${_formatClock(start)}~';
  }
  final end = start.add(Duration(seconds: item.targetSeconds));
  return '${_formatClock(start)}~${_formatClock(end)}';
}

bool sameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 지금 시각이 계획 구간 안이면 해당 항목 (미완료·시작·종료 시각이 모두 있을 때).
PlanItem? activePlanItemForNow(TodayPlan? plan, DateTime now) {
  if (plan == null) return null;
  final t = now.toLocal();
  for (final item in plan.items) {
    if (item.isDone) continue;
    final start = item.scheduledStartAt?.toLocal();
    if (start == null) continue;
    if (item.targetSeconds > 0) {
      final end = start.add(Duration(seconds: item.targetSeconds));
      if (!t.isBefore(start) && t.isBefore(end)) return item;
    } else if (!t.isBefore(start)) {
      return item;
    }
  }
  return null;
}

/// 시간 구간 없을 때 과목명으로 오늘 계획 항목 매칭.
PlanItem? planItemMatchingSubject(TodayPlan? plan, String subject) {
  final s = subject.trim();
  if (plan == null || s.isEmpty) return null;
  for (final item in plan.items) {
    if (item.isDone) continue;
    if (item.subject.trim() == s) return item;
  }
  return null;
}

String _formatClock(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

int planFocusPercent(PlanItem item) =>
    (item.completionRate.clamp(0.0, 1.0) * 100).round();

String subjectShortLabel(String subject) {
  final s = subject.trim();
  if (s.isEmpty) return '?';
  const oneChar = {'국어': '국', '영어': '영', '수학': '수', '과학': '과', '사회': '사', '역사': '역'};
  if (oneChar.containsKey(s)) return oneChar[s]!;
  if (s.length <= 2) return s;
  return s.substring(0, 1);
}

String subjectsAbbrevLine(List<String> subjects, {int max = 3}) {
  if (subjects.isEmpty) return '';
  final shown = subjects.take(max).map(subjectShortLabel).join('·');
  if (subjects.length > max) return '$shown+${subjects.length - max}';
  return shown;
}
