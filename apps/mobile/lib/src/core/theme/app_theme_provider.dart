import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme_id.dart';
import 'app_theme_store.dart';

/// 현재 앱 색 테마 (설정 시트에서 변경).
final appThemeIdProvider =
    NotifierProvider<AppThemeIdNotifier, AppThemeId>(AppThemeIdNotifier.new);

class AppThemeIdNotifier extends Notifier<AppThemeId> {
  @override
  AppThemeId build() {
    Future.microtask(_restore);
    return AppThemeId.setudyWine;
  }

  Future<void> _restore() async {
    final saved = await AppThemeStore.load();
    state = saved;
  }

  Future<void> setTheme(AppThemeId id) async {
    if (state == id) return;
    state = id;
    await AppThemeStore.save(id);
  }
}
