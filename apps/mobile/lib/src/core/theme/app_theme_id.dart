/// 앱 색 테마 (집중·셋터디 설정에서 선택).
enum AppThemeId {
  setudyWine,
  uosMint,
  yonseiRoyal,
  hufsGreen,
  hufsGray,
  kyungheeGold,
}

extension AppThemeIdX on AppThemeId {
  static const storageKey = 'setudy_app_theme_id_v1';

  String get storageValue => name;

  static AppThemeId? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final id in AppThemeId.values) {
      if (id.name == raw) return id;
    }
    return null;
  }
}
