import '../../data/plan_models.dart';

/// 현재 시각에서 가장 가까운 5분 단위 (당일 분, 05:00~23:55).
int nearestFiveMinuteOfDay(DateTime time) {
  final total = time.hour * 60 + time.minute;
  return ((total / 5).round() * 5).clamp(5 * 60, 23 * 60 + 55);
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
  if (item.scheduledStartAt == null || item.targetSeconds <= 0) {
    return item.scheduledStartAt != null
        ? _formatClock(item.scheduledStartAt!.toLocal())
        : '시간 미정';
  }
  final start = item.scheduledStartAt!.toLocal();
  final end = start.add(Duration(seconds: item.targetSeconds));
  return '${_formatClock(start)}~${_formatClock(end)}';
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
