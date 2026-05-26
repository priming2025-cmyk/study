import 'package:flutter/material.dart';

/// Study-up 브랜드 팔레트 — Wine Red 감성 (대학생 인스타그램 스타일).
/// Primary  : Wine Red   #8B162D  → 깊고 고급스러운 와인 레드
/// Secondary: Dusty Rose #B0506E  → 소프트한 로즈 포인트
/// Tertiary : Warm Caramel #C47B50 → 따뜻한 카라멜 엑센트
abstract final class AppColorSchemes {
  static ColorScheme light() {
    const primary = Color(0xFF8B162D);            // Wine Red
    const onPrimary = Color(0xFFFFFFFF);
    const primaryContainer = Color(0xFFFFDDE4);   // Blush 100
    const onPrimaryContainer = Color(0xFF3A0010); // Deep wine for text

    const secondary = Color(0xFFB0506E);          // Dusty Rose
    const onSecondary = Color(0xFFFFFFFF);
    const secondaryContainer = Color(0xFFFFDDE8); // Light rose
    const onSecondaryContainer = Color(0xFF4A152A);

    const tertiary = Color(0xFFC47B50);           // Warm Caramel
    const onTertiary = Color(0xFFFFFFFF);
    const tertiaryContainer = Color(0xFFFAEBD7);  // Cream
    const onTertiaryContainer = Color(0xFF4A2810);

    const surface = Color(0xFFFFFBFC);            // 미세하게 따뜻한 화이트
    const onSurface = Color(0xFF1A0A0D);          // 거의 블랙 (따뜻한 톤)
    const surfaceContainerLowest = Color(0xFFFFFFFF);
    const surfaceContainerLow = Color(0xFFFFF5F6);   // 매우 연한 블러쉬
    const surfaceContainer = Color(0xFFF8EAED);      // 연한 블러쉬
    const surfaceContainerHigh = Color(0xFFF0D8DD);  // 소프트 블러쉬
    const onSurfaceVariant = Color(0xFF725258);       // 따뜻한 그레이

    const outline = Color(0xFFDFC3C8);            // 소프트 로즈 그레이
    const outlineVariant = Color(0xFFF0E1E5);     // 거의 안 보이는 경계

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
      shadow: Color(0x1A1A0A0D),
      scrim: Color(0x801A0A0D),
      inverseSurface: Color(0xFF2A1215),
      onInverseSurface: Color(0xFFF5E8EA),
      inversePrimary: Color(0xFFE8899A), // 밝은 로즈 (다크 배경용)
    );
  }

  static ColorScheme dark() {
    const primary = Color(0xFFE8899A);            // 밝은 로즈 (다크 모드 primary)
    const onPrimary = Color(0xFF520018);
    const primaryContainer = Color(0xFF6E1028);   // 중간 와인 (컨테이너)
    const onPrimaryContainer = Color(0xFFFFDDE4);

    const secondary = Color(0xFFD4899B);          // 소프트 로즈
    const onSecondary = Color(0xFF3A0D1C);
    const secondaryContainer = Color(0xFF6B1F36); // 다크 로즈
    const onSecondaryContainer = Color(0xFFFFDDE8);

    const surface = Color(0xFF12080A);            // 딥 와인 블랙
    const onSurface = Color(0xFFF5E8EA);
    const surfaceContainerLowest = Color(0xFF0A0405);
    const surfaceContainerLow = Color(0xFF1C0C10);  // 매우 어두운 와인
    const surfaceContainer = Color(0xFF2A1216);     // 어두운 와인
    const surfaceContainerHigh = Color(0xFF3A1C22); // 미디엄 다크 와인
    const onSurfaceVariant = Color(0xFFC4A0A8);     // 따뜻한 연그레이

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
      tertiary: Color(0xFFD4A070),               // 따뜻한 카라멜 (다크)
      onTertiary: Color(0xFF3A2010),
      tertiaryContainer: Color(0xFF5A3820),
      onTertiaryContainer: Color(0xFFFAEBD7),
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
      outline: Color(0xFF3A1C22),
      outlineVariant: Color(0xFF2A1216),
      shadow: Color(0x80000000),
      scrim: Color(0xCC000000),
      inverseSurface: Color(0xFFF0D8DD),
      onInverseSurface: Color(0xFF1A0A0D),
      inversePrimary: Color(0xFF8B162D),         // Wine Red (라이트 배경용)
    );
  }
}
