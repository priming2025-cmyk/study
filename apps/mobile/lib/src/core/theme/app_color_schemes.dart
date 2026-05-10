import 'package:flutter/material.dart';

/// Study-up 브랜드 팔레트 — 차분한 슬레이트 베이스 + 블루 포인트(모던·대학생 톤).
abstract final class AppColorSchemes {
  /// 라이트: 밝은 캔버스, 낮은 채도, 카드는 살짝 떠 있는 느낌.
  static ColorScheme light() {
    const primary = Color(0xFF2563EB);
    const onPrimary = Color(0xFFFFFFFF);
    const primaryContainer = Color(0xFFDBEAFE);
    const onPrimaryContainer = Color(0xFF1E3A8A);

    const secondary = Color(0xFF0D9488);
    const onSecondary = Color(0xFFFFFFFF);
    const secondaryContainer = Color(0xFFCCFBF1);
    const onSecondaryContainer = Color(0xFF134E4A);

    const tertiary = Color(0xFF7C3AED);
    const onTertiary = Color(0xFFFFFFFF);
    const tertiaryContainer = Color(0xFFEDE9FE);
    const onTertiaryContainer = Color(0xFF4C1D95);

    const surface = Color(0xFFF8FAFC);
    const onSurface = Color(0xFF0F172A);
    const surfaceContainerLowest = Color(0xFFFFFFFF);
    const surfaceContainerLow = Color(0xFFF1F5F9);
    const surfaceContainer = Color(0xFFE2E8F0);
    const surfaceContainerHigh = Color(0xFFCBD5E1);
    const onSurfaceVariant = Color(0xFF475569);

    const outline = Color(0xFFCBD5E1);
    const outlineVariant = Color(0xFFE2E8F0);

    return const ColorScheme(
      brightness: Brightness.light,
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
      error: Color(0xFFDC2626),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceContainerHigh,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainer: surfaceContainer,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainerLowest: surfaceContainerLowest,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: Color(0x1A0F172A),
      scrim: Color(0x800F172A),
      inverseSurface: Color(0xFF1E293B),
      onInverseSurface: Color(0xFFF1F5F9),
      inversePrimary: Color(0xFF93C5FD),
    );
  }

  /// 다크: 딥 네이비 표면, 포인트 컬러는 한 톤 밝게.
  static ColorScheme dark() {
    const primary = Color(0xFF60A5FA);
    const onPrimary = Color(0xFF0F172A);
    const primaryContainer = Color(0xFF1E3A8A);
    const onPrimaryContainer = Color(0xFFDBEAFE);

    const secondary = Color(0xFF2DD4BF);
    const onSecondary = Color(0xFF042F2E);
    const secondaryContainer = Color(0xFF115E59);
    const onSecondaryContainer = Color(0xFFCCFBF1);

    const surface = Color(0xFF0F172A);
    const onSurface = Color(0xFFF1F5F9);
    const surfaceContainerLowest = Color(0xFF020617);
    const surfaceContainerLow = Color(0xFF1E293B);
    const surfaceContainer = Color(0xFF334155);
    const surfaceContainerHigh = Color(0xFF475569);
    const onSurfaceVariant = Color(0xFF94A3B8);

    return const ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: Color(0xFFA78BFA),
      onTertiary: Color(0xFF1E1B4B),
      tertiaryContainer: Color(0xFF5B21B6),
      onTertiaryContainer: Color(0xFFEDE9FE),
      error: Color(0xFFF87171),
      onError: Color(0xFF450A0A),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFEE2E2),
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceContainerHigh,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainer: surfaceContainer,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainerLowest: surfaceContainerLowest,
      onSurfaceVariant: onSurfaceVariant,
      outline: Color(0xFF475569),
      outlineVariant: Color(0xFF334155),
      shadow: Color(0x66000000),
      scrim: Color(0xCC000000),
      inverseSurface: Color(0xFFE2E8F0),
      onInverseSurface: Color(0xFF0F172A),
      inversePrimary: Color(0xFF1D4ED8),
    );
  }
}
