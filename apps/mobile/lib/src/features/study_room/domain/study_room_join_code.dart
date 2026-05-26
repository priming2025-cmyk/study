import 'dart:math';

/// 혼동하기 쉬운 0/O, 1/I 제외.
const _joinCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// 6자리 입장코드 생성.
String generateStudyRoomJoinCode() {
  final r = Random.secure();
  return List.generate(
    6,
    (_) => _joinCodeAlphabet[r.nextInt(_joinCodeAlphabet.length)],
  ).join();
}

/// 사용자 입력을 입장코드 형식으로 정규화.
String normalizeJoinCode(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();

/// UUID가 아닌 짧은 입장코드 형식인지.
bool looksLikeJoinCode(String entry) {
  final n = normalizeJoinCode(entry);
  if (n.isEmpty) return false;
  if (n.contains('-') && n.length > 12) return false;
  return n.length >= 4 && n.length <= 8;
}
