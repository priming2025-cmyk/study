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
