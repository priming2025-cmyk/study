import 'package:shared_preferences/shared_preferences.dart';

/// Universal Link `/friend?ref=` 로 들어온 초대자 UUID (로그인 후 처리).
abstract final class PendingFriendInvite {
  static const _key = 'setudy_pending_friend_invite_ref';

  static Future<void> save(String referrerUserId) async {
    final ref = referrerUserId.trim();
    if (ref.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, ref);
  }

  /// 저장된 ref를 읽고 삭제. 없으면 null.
  static Future<String?> consume() async {
    final sp = await SharedPreferences.getInstance();
    final ref = sp.getString(_key)?.trim();
    if (ref == null || ref.isEmpty) return null;
    await sp.remove(_key);
    return ref;
  }
}
