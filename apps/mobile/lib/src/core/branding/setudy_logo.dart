import 'package:flutter/material.dart';

/// Setudy 브랜드 로고 (아이콘 + 워드마크).
class SetudyLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final Color? wordmarkColor;
  final bool showWordmark;
  final bool _onDarkHeader;

  const SetudyLogo({
    super.key,
    this.iconSize = 42,
    this.fontSize = 24,
    this.wordmarkColor,
    this.showWordmark = true,
  }) : _onDarkHeader = false;

  /// 로그인 헤더용 — 흰색 워드마크·밝은 아이콘 박스.
  const SetudyLogo.lightHeader({
    super.key,
    this.iconSize = 42,
    this.fontSize = 24,
  })  : wordmarkColor = Colors.white,
        showWordmark = true,
        _onDarkHeader = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textColor = wordmarkColor ?? cs.primary;
    final onDark = _onDarkHeader;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            gradient: onDark
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary,
                      Color.lerp(cs.primary, const Color(0xFF10B981), 0.55)!,
                    ],
                  ),
            color: onDark ? Colors.white.withValues(alpha: 0.22) : null,
            borderRadius: BorderRadius.circular(iconSize * 0.28),
            border: onDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.35))
                : null,
            boxShadow: onDark
                ? null
                : [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              'S',
              style: TextStyle(
                color: onDark ? Colors.white : cs.onPrimary,
                fontSize: iconSize * 0.52,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
        if (showWordmark) ...[
          SizedBox(width: iconSize * 0.28),
          Text(
            'Setudy',
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}
