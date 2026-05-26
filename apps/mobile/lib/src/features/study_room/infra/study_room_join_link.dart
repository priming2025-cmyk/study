import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../domain/study_room_join_code.dart';

/// 초대 메시지·공유용 웹 딥링크 (SPA `/room/join?code=`).
String studyRoomJoinLink(String joinCode) {
  final code = normalizeJoinCode(joinCode);
  final configured = dotenv.env['SETUDY_WEB_URL']?.trim();
  final base = (configured != null && configured.isNotEmpty)
      ? configured.replaceAll(RegExp(r'/$'), '')
      : (kIsWeb ? Uri.base.origin : '');
  if (base.isEmpty) {
    return '/room/join?code=$code';
  }
  return '$base/room/join?code=${Uri.encodeComponent(code)}';
}

String studyRoomInviteMessage({
  required String joinCode,
  String? goalText,
}) {
  final link = studyRoomJoinLink(joinCode);
  final goalLine =
      goalText != null && goalText.trim().isNotEmpty ? '\n목표: ${goalText.trim()}' : '';
  return '우리 같이 공부하자!$goalLine\n'
      '입장코드: ${normalizeJoinCode(joinCode)}\n'
      '바로 입장: $link';
}
