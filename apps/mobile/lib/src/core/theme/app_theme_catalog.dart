import 'package:flutter/material.dart';

import 'app_theme_id.dart';

/// 테마 메타 + 라이트/다크 [ColorScheme].
class AppThemeDefinition {
  const AppThemeDefinition({
    required this.id,
    required this.labelKo,
    required this.swatch,
    required this.light,
    required this.dark,
  });

  final AppThemeId id;
  final String labelKo;
  final Color swatch;
  final ColorScheme light;
  final ColorScheme dark;
}

abstract final class AppThemeCatalog {
  static AppThemeDefinition get(AppThemeId id) =>
      all.firstWhere((t) => t.id == id);

  static final all = <AppThemeDefinition>[
    _setudyWine,
    _snuBlue,
    _yonseiRoyal,
    _hufsGreen,
    _hufsGray,
    _kyungheeGold,
    _uosMint,
  ];

  // ── 1. Setudy Wine (기본) — 고려·경희 계열 와인 레드 ──
  static final _setudyWine = AppThemeDefinition(
    id: AppThemeId.setudyWine,
    labelKo: '와인',
    swatch: const Color(0xFF8B162D),
    light: _Palette(
      primary: Color(0xFF8B162D),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFFFE8EC),
      onPrimaryContainer: Color(0xFF3A0010),
      secondary: Color(0xFF6B5B5E),
      secondaryContainer: Color(0xFFF3EDEF),
      tertiary: Color(0xFF8A7468),
      tertiaryContainer: Color(0xFFF5EDE9),
      surface: Color(0xFFFFFFFF),
      surfaceLow: Color(0xFFFAF7F7),
      surfaceMid: Color(0xFFF3EEEF),
      surfaceHigh: Color(0xFFEDE6E8),
      onSurface: Color(0xFF1C1417),
      onSurfaceVariant: Color(0xFF6B5E62),
      outline: Color(0xFFC9B8BB),
      outlineVariant: Color(0xFFEDE6E8),
      inversePrimary: Color(0xFFE8899A),
    ).light,
    dark: _Palette(
      primary: Color(0xFFE8899A),
      onPrimary: Color(0xFF520018),
      primaryContainer: Color(0xFF6E1028),
      onPrimaryContainer: Color(0xFFFFE8EC),
      secondary: Color(0xFFBFAAAD),
      secondaryContainer: Color(0xFF4A3A3D),
      tertiary: Color(0xFFBFAA9E),
      tertiaryContainer: Color(0xFF4A3A30),
      surface: Color(0xFF161012),
      surfaceLow: Color(0xFF1E1618),
      surfaceMid: Color(0xFF281D20),
      surfaceHigh: Color(0xFF332528),
      onSurface: Color(0xFFF5EEF0),
      onSurfaceVariant: Color(0xFFBFACB0),
      outline: Color(0xFF4A3A3D),
      outlineVariant: Color(0xFF332528),
      inversePrimary: Color(0xFF8B162D),
      brightness: Brightness.dark,
    ).scheme,
  );

  // ── 2. SNU Blue — 서울대 전용색 + 베이지·골드 포인트 ──
  //    RGB(15,15,112) · [identity.snu.ac.kr](https://identity.snu.ac.kr/color/1)
  static final _snuBlue = AppThemeDefinition(
    id: AppThemeId.snuBlue,
    labelKo: '서울대',
    swatch: const Color(0xFF0F0F70),
    light: _Palette(
      primary: Color(0xFF0F0F70),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE8E8F5),
      onPrimaryContainer: Color(0xFF06063A),
      secondary: Color(0xFF6E6E78),
      secondaryContainer: Color(0xFFF0EBE3),
      tertiary: Color(0xFFB8973A),
      tertiaryContainer: Color(0xFFFFF6E0),
      surface: Color(0xFFFFFCF8),
      surfaceLow: Color(0xFFF7F2EA),
      surfaceMid: Color(0xFFEDE8DF),
      surfaceHigh: Color(0xFFE0DAD0),
      onSurface: Color(0xFF12121F),
      onSurfaceVariant: Color(0xFF5C5C68),
      outline: Color(0xFFC8C4BC),
      outlineVariant: Color(0xFFE8E4DC),
      inversePrimary: Color(0xFF8B8BD4),
    ).light,
    dark: _Palette(
      primary: Color(0xFF9B9BE8),
      onPrimary: Color(0xFF0A0A40),
      primaryContainer: Color(0xFF1A1A88),
      onPrimaryContainer: Color(0xFFE8E8F8),
      secondary: Color(0xFFB0B0BA),
      secondaryContainer: Color(0xFF3A3A44),
      tertiary: Color(0xFFD4B85A),
      tertiaryContainer: Color(0xFF5A4A18),
      surface: Color(0xFF0E0E18),
      surfaceLow: Color(0xFF161622),
      surfaceMid: Color(0xFF1E1E2C),
      surfaceHigh: Color(0xFF282836),
      onSurface: Color(0xFFF0F0F8),
      onSurfaceVariant: Color(0xFFA8A8B4),
      outline: Color(0xFF3A3A48),
      outlineVariant: Color(0xFF282836),
      inversePrimary: Color(0xFF0F0F70),
      brightness: Brightness.dark,
    ).scheme,
  );

  // ── 3. Yonsei Royal Blue ──
  static final _yonseiRoyal = AppThemeDefinition(
    id: AppThemeId.yonseiRoyal,
    labelKo: '연세',
    swatch: const Color(0xFF003876),
    light: _Palette(
      primary: Color(0xFF003876),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE3EDF8),
      onPrimaryContainer: Color(0xFF001A38),
      secondary: Color(0xFF5A6570),
      secondaryContainer: Color(0xFFEEF2F6),
      tertiary: Color(0xFF4A6FA5),
      tertiaryContainer: Color(0xFFE8F0FA),
      surface: Color(0xFFFFFFFF),
      surfaceLow: Color(0xFFF6F9FC),
      surfaceMid: Color(0xFFE8EFF6),
      surfaceHigh: Color(0xFFD8E4EF),
      onSurface: Color(0xFF0A1628),
      onSurfaceVariant: Color(0xFF556070),
      outline: Color(0xFFB8C8D8),
      outlineVariant: Color(0xFFE0E8F0),
      inversePrimary: Color(0xFF6BA3E0),
    ).light,
    dark: _Palette(
      primary: Color(0xFF7EB8F0),
      onPrimary: Color(0xFF001830),
      primaryContainer: Color(0xFF004890),
      onPrimaryContainer: Color(0xFFE3EDF8),
      secondary: Color(0xFFA8B4C0),
      secondaryContainer: Color(0xFF2A3848),
      tertiary: Color(0xFF88B0E0),
      tertiaryContainer: Color(0xFF1A3868),
      surface: Color(0xFF080E18),
      surfaceLow: Color(0xFF101820),
      surfaceMid: Color(0xFF182028),
      surfaceHigh: Color(0xFF202830),
      onSurface: Color(0xFFE8F0F8),
      onSurfaceVariant: Color(0xFFA0B0C0),
      outline: Color(0xFF304050),
      outlineVariant: Color(0xFF202830),
      inversePrimary: Color(0xFF003876),
      brightness: Brightness.dark,
    ).scheme,
  );

  // ── 4. HUFS Green ──
  static final _hufsGreen = AppThemeDefinition(
    id: AppThemeId.hufsGreen,
    labelKo: '외대',
    swatch: const Color(0xFF006B3F),
    light: _Palette(
      primary: Color(0xFF006B3F),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE0F5EC),
      onPrimaryContainer: Color(0xFF002818),
      secondary: Color(0xFF5C6860),
      secondaryContainer: Color(0xFFEEF2F0),
      tertiary: Color(0xFF3D8A62),
      tertiaryContainer: Color(0xFFE8F5EE),
      surface: Color(0xFFFFFFFF),
      surfaceLow: Color(0xFFF6FAF8),
      surfaceMid: Color(0xFFE8F0EC),
      surfaceHigh: Color(0xFFD8E8E0),
      onSurface: Color(0xFF0A1810),
      onSurfaceVariant: Color(0xFF506058),
      outline: Color(0xFFB8CCC0),
      outlineVariant: Color(0xFFE0ECE6),
      inversePrimary: Color(0xFF5CC090),
    ).light,
    dark: _Palette(
      primary: Color(0xFF6CD8A0),
      onPrimary: Color(0xFF002818),
      primaryContainer: Color(0xFF005030),
      onPrimaryContainer: Color(0xFFE0F5EC),
      secondary: Color(0xFFA8B8B0),
      secondaryContainer: Color(0xFF2A3830),
      tertiary: Color(0xFF88D0A8),
      tertiaryContainer: Color(0xFF1A4830),
      surface: Color(0xFF080E0A),
      surfaceLow: Color(0xFF101810),
      surfaceMid: Color(0xFF182018),
      surfaceHigh: Color(0xFF202820),
      onSurface: Color(0xFFE8F5EE),
      onSurfaceVariant: Color(0xFFA0B0A8),
      outline: Color(0xFF304038),
      outlineVariant: Color(0xFF202820),
      inversePrimary: Color(0xFF006B3F),
      brightness: Brightness.dark,
    ).scheme,
  );

  // ── 5. HUFS Gray — 차분한 그레이 + 그린 포인트 ──
  static final _hufsGray = AppThemeDefinition(
    id: AppThemeId.hufsGray,
    labelKo: '외대 그레이',
    swatch: const Color(0xFF4A5550),
    light: _Palette(
      primary: Color(0xFF4A5550),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE8EEEB),
      onPrimaryContainer: Color(0xFF1A2420),
      secondary: Color(0xFF6B7570),
      secondaryContainer: Color(0xFFF0F2F1),
      tertiary: Color(0xFF006B3F),
      tertiaryContainer: Color(0xFFE0F0E8),
      surface: Color(0xFFFFFFFF),
      surfaceLow: Color(0xFFF8F9F8),
      surfaceMid: Color(0xFFEEF0EF),
      surfaceHigh: Color(0xFFE2E6E4),
      onSurface: Color(0xFF141A18),
      onSurfaceVariant: Color(0xFF5A6460),
      outline: Color(0xFFC0C8C4),
      outlineVariant: Color(0xFFE4E8E6),
      inversePrimary: Color(0xFF98A8A0),
    ).light,
    dark: _Palette(
      primary: Color(0xFFB0C0B8),
      onPrimary: Color(0xFF1A2420),
      primaryContainer: Color(0xFF3A4844),
      onPrimaryContainer: Color(0xFFE8EEEB),
      secondary: Color(0xFF909A96),
      secondaryContainer: Color(0xFF343C38),
      tertiary: Color(0xFF6CD8A0),
      tertiaryContainer: Color(0xFF1A4030),
      surface: Color(0xFF0E1010),
      surfaceLow: Color(0xFF161818),
      surfaceMid: Color(0xFF1E2020),
      surfaceHigh: Color(0xFF282A28),
      onSurface: Color(0xFFF0F2F1),
      onSurfaceVariant: Color(0xFFA0AAA6),
      outline: Color(0xFF404846),
      outlineVariant: Color(0xFF282A28),
      inversePrimary: Color(0xFF4A5550),
      brightness: Brightness.dark,
    ).scheme,
  );

  // ── 6. Kyung Hee Gold ──
  static final _kyungheeGold = AppThemeDefinition(
    id: AppThemeId.kyungheeGold,
    labelKo: '경희',
    swatch: const Color(0xFFB8860B),
    light: _Palette(
      primary: Color(0xFFB8860B),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFFFF4D8),
      onPrimaryContainer: Color(0xFF3A2800),
      secondary: Color(0xFF6B6050),
      secondaryContainer: Color(0xFFF5F0E8),
      tertiary: Color(0xFF8B6914),
      tertiaryContainer: Color(0xFFFFF0D0),
      surface: Color(0xFFFFFCF6),
      surfaceLow: Color(0xFFFAF6EE),
      surfaceMid: Color(0xFFF0EAE0),
      surfaceHigh: Color(0xFFE4DCD0),
      onSurface: Color(0xFF1C1810),
      onSurfaceVariant: Color(0xFF6B6058),
      outline: Color(0xFFD0C4B0),
      outlineVariant: Color(0xFFEAE4D8),
      inversePrimary: Color(0xFFE8C060),
    ).light,
    dark: _Palette(
      primary: Color(0xFFE8C060),
      onPrimary: Color(0xFF3A2800),
      primaryContainer: Color(0xFF7A5808),
      onPrimaryContainer: Color(0xFFFFF4D8),
      secondary: Color(0xFFB8A898),
      secondaryContainer: Color(0xFF403830),
      tertiary: Color(0xFFD0A848),
      tertiaryContainer: Color(0xFF5A4010),
      surface: Color(0xFF141008),
      surfaceLow: Color(0xFF1C1810),
      surfaceMid: Color(0xFF242018),
      surfaceHigh: Color(0xFF2C2820),
      onSurface: Color(0xFFF8F4EC),
      onSurfaceVariant: Color(0xFFB8A898),
      outline: Color(0xFF484038),
      outlineVariant: Color(0xFF2C2820),
      inversePrimary: Color(0xFFB8860B),
      brightness: Brightness.dark,
    ).scheme,
  );

  // ── 7. UOS Mint Sky ──
  static final _uosMint = AppThemeDefinition(
    id: AppThemeId.uosMint,
    labelKo: '서울시립',
    swatch: const Color(0xFF3BA8B8),
    light: _Palette(
      primary: Color(0xFF3BA8B8),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE0F6FA),
      onPrimaryContainer: Color(0xFF003840),
      secondary: Color(0xFF5A6A6E),
      secondaryContainer: Color(0xFFEEF4F6),
      tertiary: Color(0xFF5CC4D8),
      tertiaryContainer: Color(0xFFE8FAFE),
      surface: Color(0xFFFFFFFF),
      surfaceLow: Color(0xFFF4FAFC),
      surfaceMid: Color(0xFFE8F4F8),
      surfaceHigh: Color(0xFFD8ECF2),
      onSurface: Color(0xFF0A181C),
      onSurfaceVariant: Color(0xFF506068),
      outline: Color(0xFFB8D0D8),
      outlineVariant: Color(0xFFE0EEF2),
      inversePrimary: Color(0xFF80D8E8),
    ).light,
    dark: _Palette(
      primary: Color(0xFF80D8E8),
      onPrimary: Color(0xFF003840),
      primaryContainer: Color(0xFF187888),
      onPrimaryContainer: Color(0xFFE0F6FA),
      secondary: Color(0xFFA0B0B8),
      secondaryContainer: Color(0xFF2A3840),
      tertiary: Color(0xFFA0E8F8),
      tertiaryContainer: Color(0xFF1A5868),
      surface: Color(0xFF080E10),
      surfaceLow: Color(0xFF101618),
      surfaceMid: Color(0xFF181E20),
      surfaceHigh: Color(0xFF20282A),
      onSurface: Color(0xFFE8F6FA),
      onSurfaceVariant: Color(0xFFA0B0B8),
      outline: Color(0xFF304048),
      outlineVariant: Color(0xFF20282A),
      inversePrimary: Color(0xFF3BA8B8),
      brightness: Brightness.dark,
    ).scheme,
  );
}

class _Palette {
  const _Palette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceMid,
    required this.surfaceHigh,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.inversePrimary,
    this.onSecondary = const Color(0xFFFFFFFF),
    this.onSecondaryContainer = const Color(0xFF1C1417),
    this.onTertiary = const Color(0xFFFFFFFF),
    this.onTertiaryContainer = const Color(0xFF1C1417),
    this.brightness = Brightness.light,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color surface;
  final Color surfaceLow;
  final Color surfaceMid;
  final Color surfaceHigh;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color inversePrimary;
  final Brightness brightness;

  ColorScheme get light => scheme;
  ColorScheme get scheme => ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        tertiaryContainer: tertiaryContainer,
        onTertiaryContainer: onTertiaryContainer,
        error: brightness == Brightness.light
            ? const Color(0xFFC62828)
            : const Color(0xFFF4838B),
        onError: brightness == Brightness.light
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF450A0A),
        errorContainer: brightness == Brightness.light
            ? const Color(0xFFFFEBEE)
            : const Color(0xFF7F1D1D),
        onErrorContainer: brightness == Brightness.light
            ? const Color(0xFF5C1010)
            : const Color(0xFFFFEBEE),
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: surfaceHigh,
        surfaceContainerHigh: surfaceHigh,
        surfaceContainer: surfaceMid,
        surfaceContainerLow: surfaceLow,
        surfaceContainerLowest:
            brightness == Brightness.light ? const Color(0xFFFFFFFF) : surface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        shadow: brightness == Brightness.light
            ? onSurface.withAlpha(26)
            : const Color(0x80000000),
        scrim: brightness == Brightness.light
            ? onSurface.withAlpha(128)
            : const Color(0xCC000000),
        inverseSurface: brightness == Brightness.light
            ? Color.lerp(onSurface, surface, 0.15)!
            : surfaceLow,
        onInverseSurface: brightness == Brightness.light ? surfaceLow : onSurface,
        inversePrimary: inversePrimary,
      );
}
