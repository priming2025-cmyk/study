import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKeyFocusDistraction = 'focus_distraction_mode_v2';
/// 이전 기본(off) 사용자 설정 유지용.
const _prefKeyFocusDistractionLegacy = 'focus_distraction_mode_v1';

/// 스터디방·세션 공통: 채팅 숨김 등 UI 차단. (실제 타 앱 차단은 OS 설정과 함께 쓰는 것을 권장)
final focusDistractionModeProvider =
    AsyncNotifierProvider<FocusDistractionNotifier, bool>(
  FocusDistractionNotifier.new,
);

class FocusDistractionNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final sp = await SharedPreferences.getInstance();
    if (sp.containsKey(_prefKeyFocusDistraction)) {
      return sp.getBool(_prefKeyFocusDistraction)!;
    }
    if (sp.containsKey(_prefKeyFocusDistractionLegacy)) {
      return sp.getBool(_prefKeyFocusDistractionLegacy)!;
    }
    return true;
  }

  Future<void> setEnabled(bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_prefKeyFocusDistraction, value);
    state = AsyncData(value);
  }

  Future<void> toggle() async {
    final cur = await future;
    await setEnabled(!cur);
  }
}
