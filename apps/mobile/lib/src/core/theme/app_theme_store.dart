import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_id.dart';

/// 선택한 색 테마를 로컬에 저장·복원.
class AppThemeStore {
  static Future<AppThemeId> load() async {
    final sp = await SharedPreferences.getInstance();
    return AppThemeIdX.tryParse(sp.getString(AppThemeIdX.storageKey)) ??
        AppThemeId.setudyWine;
  }

  static Future<void> save(AppThemeId id) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(AppThemeIdX.storageKey, id.storageValue);
  }
}
