import 'package:flutter/material.dart';

/// Study-up 브랜드 팔레트 — Instagram 미니멀 감성.
/// 메인 컬러 하나(Wine Red #8B162D)만 강하게, 나머지는 완전 중성 warm-gray.
/// Primary : Wine Red  #8B162D  → 깊고 고급스러운 와인 레드
/// 나머지  : Warm Gray 계열     → 방해 없이 메인 컬러를 돋보이게
abstract final class AppColorSchemes {
  static ColorScheme light() {
    const primary = Color(0xFF8B162D);            // Wine Red
    const onPrimary = Color(0xFFFFFFFF);
    const primaryContainer = Color(0xFFFFE8EC);   // 아주 연한 블러쉬 (거의 흰색)
    const onPrimaryContainer = Color(0xFF3A0010);

    // secondary / tertiary: 컬러 경쟁 없는 warm neutral gray
    const secondary = Color(0xFF6B5B5E);          // Warm Muted Gray
    const onSecondary = Color(0xFFFFFFFF);
    const secondaryContainer = Color(0xFFF3EDEF); // 거의 흰색
    const onSecondaryContainer = Color(0xFF2B1F21);

    const tertiary = Color(0xFF8A7468);           // Warm Brown-Gray
    const onTertiary = Color(0xFFFFFFFF);
    const tertiaryContainer = Color(0xFFF5EDE9);
    const onTertiaryContainer = Color(0xFF2E2018);

    // 표면: 순백 + 아주 미세한 warm tint → 차갑지 않고 따뜻한 느낌
    const surface = Color(0xFFFFFFFF);
    const onSurface = Color(0xFF1C1417);          // 따뜻한 near-black
    const surfaceContainerLowest = Color(0xFFFFFFFF);
    const surfaceContainerLow = Color(0xFFFAF7F7); // 거의 흰색
    const surfaceContainer = Color(0xFFF3EEEF);    // 아주 연한 warm gray
    const surfaceContainerHigh = Color(0xFFEDE6E8);
    const onSurfaceVariant = Color(0xFF6B5E62);    // Warm medium gray

    const outline = Color(0xFFC9B8BB);             // 얇고 부드러운 경계
    const outlineVariant = Color(0xFFEDE6E8);

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
      error: Color(0xFFC62828),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFEBEE),
      onErrorContainer: Color(0xFF5C1010),
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
      shadow: Color(0x1A1C1417),
      scrim: Color(0x801C1417),
      inverseSurface: Color(0xFF2A1E21),
      onInverseSurface: Color(0xFFF5EEF0),
      inversePrimary: Color(0xFFE8899A),
    );
  }

  static ColorScheme dark() {
    const primary = Color(0xFFE8899A);            // 밝은 로즈 (다크 primary)
    const onPrimary = Color(0xFF520018);
    const primaryContainer = Color(0xFF6E1028);
    const onPrimaryContainer = Color(0xFFFFE8EC);

    const secondary = Color(0xFFBFAAAD);          // Warm light gray
    const onSecondary = Color(0xFF3A2A2D);
    const secondaryContainer = Color(0xFF4A3A3D);
    const onSecondaryContainer = Color(0xFFF3EDEF);

    const tertiary = Color(0xFFBFAA9E);
    const onTertiary = Color(0xFF3A2A20);
    const tertiaryContainer = Color(0xFF4A3A30);
    const onTertiaryContainer = Color(0xFFF5EDE9);

    // 다크: 순수 따뜻한 블랙 계열 (차갑지 않게)
    const surface = Color(0xFF161012);
    const onSurface = Color(0xFFF5EEF0);
    const surfaceContainerLowest = Color(0xFF0E0A0B);
    const surfaceContainerLow = Color(0xFF1E1618);
    const surfaceContainer = Color(0xFF281D20);
    const surfaceContainerHigh = Color(0xFF332528);
    const onSurfaceVariant = Color(0xFFBFACB0);

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
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: Color(0xFFF4838B),
      onError: Color(0xFF450A0A),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFFEBEE),
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceContainerHigh,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainer: surfaceContainer,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainerLowest: surfaceContainerLowest,
      onSurfaceVariant: onSurfaceVariant,
      outline: Color(0xFF4A3A3D),
      outlineVariant: Color(0xFF332528),
      shadow: Color(0x80000000),
      scrim: Color(0xCC000000),
      inverseSurface: Color(0xFFF3EEEF),
      onInverseSurface: Color(0xFF1C1417),
      inversePrimary: Color(0xFF8B162D),
    );
  }
}
