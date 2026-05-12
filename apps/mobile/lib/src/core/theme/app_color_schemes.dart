import 'package:flutter/material.dart';

/// Study-up 브랜드 팔레트 — Sky Blue + Emerald Mint (Toss·MZ 감성).
/// Primary  : Sky 500  #0EA5E9  →  차갑고 신선한 하늘색
/// Secondary: Emerald  #10B981  →  에너지 있는 민트 포인트
/// Surface  : Cool Gray 계열   →  깔끔하고 현대적
abstract final class AppColorSchemes {
  static ColorScheme light() {
    const primary = Color(0xFF0EA5E9);          // Sky 500
    const onPrimary = Color(0xFFFFFFFF);
    const primaryContainer = Color(0xFFE0F2FE); // Sky 100
    const onPrimaryContainer = Color(0xFF0C4A6E); // Sky 900

    const secondary = Color(0xFF10B981);         // Emerald 500
    const onSecondary = Color(0xFFFFFFFF);
    const secondaryContainer = Color(0xFFD1FAE5); // Emerald 100
    const onSecondaryContainer = Color(0xFF064E3B); // Emerald 900

    const tertiary = Color(0xFF6366F1);          // Indigo 500 (강조 액센트)
    const onTertiary = Color(0xFFFFFFFF);
    const tertiaryContainer = Color(0xFFE0E7FF); // Indigo 100
    const onTertiaryContainer = Color(0xFF312E81);

    const surface = Color(0xFFF8FAFC);           // Slate 50
    const onSurface = Color(0xFF0F172A);         // Slate 900
    const surfaceContainerLowest = Color(0xFFFFFFFF);
    const surfaceContainerLow = Color(0xFFF1F5F9);  // Slate 100
    const surfaceContainer = Color(0xFFE2E8F0);     // Slate 200
    const surfaceContainerHigh = Color(0xFFCBD5E1); // Slate 300
    const onSurfaceVariant = Color(0xFF64748B);     // Slate 500

    const outline = Color(0xFFCBD5E1);          // Slate 300
    const outlineVariant = Color(0xFFE2E8F0);   // Slate 200

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
      error: Color(0xFFEF4444),
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
      inversePrimary: Color(0xFF7DD3FC), // Sky 300
    );
  }

  static ColorScheme dark() {
    const primary = Color(0xFF38BDF8);           // Sky 400
    const onPrimary = Color(0xFF082F49);         // Sky 950
    const primaryContainer = Color(0xFF0369A1);  // Sky 700
    const onPrimaryContainer = Color(0xFFE0F2FE);

    const secondary = Color(0xFF34D399);         // Emerald 400
    const onSecondary = Color(0xFF022C22);
    const secondaryContainer = Color(0xFF065F46); // Emerald 800
    const onSecondaryContainer = Color(0xFFD1FAE5);

    const surface = Color(0xFF0B1120);           // 딥 슬레이트 (Toss 다크 느낌)
    const onSurface = Color(0xFFF1F5F9);
    const surfaceContainerLowest = Color(0xFF060D18);
    const surfaceContainerLow = Color(0xFF111827); // Gray 900
    const surfaceContainer = Color(0xFF1F2937);    // Gray 800
    const surfaceContainerHigh = Color(0xFF374151);// Gray 700
    const onSurfaceVariant = Color(0xFF9CA3AF);    // Gray 400

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
      tertiary: Color(0xFF818CF8),               // Indigo 400
      onTertiary: Color(0xFF1E1B4B),
      tertiaryContainer: Color(0xFF3730A3),
      onTertiaryContainer: Color(0xFFE0E7FF),
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
      outline: Color(0xFF374151),
      outlineVariant: Color(0xFF1F2937),
      shadow: Color(0x66000000),
      scrim: Color(0xCC000000),
      inverseSurface: Color(0xFFE2E8F0),
      onInverseSurface: Color(0xFF0F172A),
      inversePrimary: Color(0xFF0284C7),         // Sky 600
    );
  }
}
