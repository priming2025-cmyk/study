import 'package:shared_preferences/shared_preferences.dart';

/// 입장 링크(`/room/join?code=`) — 로그인 전에도 보관 후 셋터디 탭에서 자동 입장.
abstract final class PendingStudyRoomJoin {
  static const _key = 'setudy_pending_room_join_code';

  static Future<void> save(String code) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, c);
  }

  static Future<String?> peek() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_key)?.trim();
  }

  static Future<String?> consume() async {
    final sp = await SharedPreferences.getInstance();
    final c = sp.getString(_key)?.trim();
    if (c == null || c.isEmpty) return null;
    await sp.remove(_key);
    return c;
  }
}
