import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_id.dart';

/// 선택한 색 테마를 로컬에 저장·복원.
class AppThemeStore {
  static Future<AppThemeId> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(AppThemeIdX.storageKey);
    // 제거된 서울대(snuBlue) → 청록(서울시립)으로 이전
    if (raw == 'snuBlue') return AppThemeId.uosMint;
    return AppThemeIdX.tryParse(raw) ?? AppThemeId.setudyWine;
  }

  static Future<void> save(AppThemeId id) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(AppThemeIdX.storageKey, id.storageValue);
  }
}
