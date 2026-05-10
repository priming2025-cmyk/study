bool looksLikeUuid(String raw) {
  final s = raw.trim();
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(s);
}

String formatFocusShort(int sec) {
  if (sec <= 0) return '0분';
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  if (h > 0) return '$h시간 $m분';
  return '$m분';
}
