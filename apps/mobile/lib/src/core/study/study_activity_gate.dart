// 공부 중 여부 — DM 알림 억제용 (솔로 세션 · 셋터디 방).
//
// 핵심 목표:
// - DM 푸시/알림이 공부 중에 들어오면 방해가 되므로, 앱이 백그라운드/종료 상태에서도 억제하기 위해
//   로컬 플래그를 SharedPreferences에 저장합니다.
import 'package:shared_preferences/shared_preferences.dart';

abstract final class StudyActivityGate {
  static const _prefKeyIsStudying = 'setudy_is_studying';

  static bool sessionRunning = false;
  static bool inStudyRoom = false;

  static bool get isStudying => sessionRunning || inStudyRoom;

  static Future<void> init() async {
    final prefs = await _prefs();
    final v = prefs.getBool(_prefKeyIsStudying);
    if (v == null) return;
    // "studying" 단일 플래그만 저장하므로, 둘 중 어느 쪽인지 구분할 수는 없습니다.
    // 목적은 알림 억제이므로 isStudying이 동일하게 동작하도록 맞춥니다.
    sessionRunning = v;
    inStudyRoom = false;
  }

  static Future<void> setSessionRunning(bool v) async {
    sessionRunning = v;
    await _persistIsStudying();
  }

  static Future<void> setInStudyRoom(bool v) async {
    inStudyRoom = v;
    await _persistIsStudying();
  }

  static Future<void> _persistIsStudying() async {
    final prefs = await _prefs();
    await prefs.setBool(_prefKeyIsStudying, isStudying);
  }

  static Future<SharedPreferences> _prefs() =>
      SharedPreferences.getInstance();
}
