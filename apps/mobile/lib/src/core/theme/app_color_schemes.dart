import 'package:flutter/material.dart';

import 'app_theme_catalog.dart';
import 'app_theme_id.dart';

/// [AppThemeId]별 라이트/다크 [ColorScheme].
abstract final class AppColorSchemes {
  static ColorScheme light([AppThemeId id = AppThemeId.setudyWine]) =>
      AppThemeCatalog.get(id).light;

  static ColorScheme dark([AppThemeId id = AppThemeId.setudyWine]) =>
      AppThemeCatalog.get(id).dark;
}
