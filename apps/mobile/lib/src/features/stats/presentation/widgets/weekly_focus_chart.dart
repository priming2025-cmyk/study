import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/daily_focus_stat.dart';

/// 주간 집중 시간 바 차트.
/// 그라데이션 바 + 오늘 날짜 펄스 애니메이션 + 호버 툴팁.
class WeeklyFocusChart extends StatefulWidget {
  final List<DailyFocusStat> stats;

  const WeeklyFocusChart({super.key, required this.stats});

  @override
  State<WeeklyFocusChart> createState() => _WeeklyFocusChartState();
}

class _WeeklyFocusChartState extends State<WeeklyFocusChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  static String _weekdayShort(DateTime d) {
    return switch (d.weekday) {
      DateTime.monday => '월',
      DateTime.tuesday => '화',
      DateTime.wednesday => '수',
      DateTime.thursday => '목',
      DateTime.friday => '금',
      DateTime.saturday => '토',
      _ => '일',
    };
  }

  static String _formatFocus(int seconds) {
    if (seconds <= 0) return '0분';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분';
    return '$m분';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final today = DateTime.now();
    final maxSec = widget.stats.fold<int>(
      1,
      (m, e) => e.focusedSeconds > m ? e.focusedSeconds : m,
    );
    final total =
        widget.stats.fold<int>(0, (a, e) => a + e.focusedSeconds);

    if (widget.stats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '공부를 끝내면 여기에 쌓여요.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 합계
        if (total > 0) ...[
          Text(
            '합계 ${_formatFocus(total)} · 막대 높이는 가장 긴 날 기준',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
        ],
        // 바 차트
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: widget.stats.asMap().entries.map((entry) {
              final i = entry.key;
              final stat = entry.value;
              final ratio =
                  maxSec <= 0 ? 0.0 : stat.focusedSeconds / maxSec;
              final isToday = stat.dayLocal.year == today.year &&
                  stat.dayLocal.month == today.month &&
                  stat.dayLocal.day == today.day;
              final isHovered = _hoveredIndex == i;
              final isWeekend = stat.dayLocal.weekday >= 6;

              return Expanded(
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _hoveredIndex = i),
                  onTapUp: (_) => setState(() => _hoveredIndex = null),
                  onTapCancel: () => setState(() => _hoveredIndex = null),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 툴팁 (탭했을 때)
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: isHovered ? 1.0 : 0.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.inverseSurface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _formatFocus(stat.focusedSeconds),
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.onInverseSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 바
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: isToday
                                ? AnimatedBuilder(
                                    animation: _pulseAnim,
                                    builder: (_, __) => _Bar(
                                      ratio: ratio * _pulseAnim.value,
                                      isToday: true,
                                      isWeekend: isWeekend,
                                      cs: cs,
                                    ),
                                  )
                                : _Bar(
                                    ratio: ratio,
                                    isToday: false,
                                    isWeekend: isWeekend,
                                    cs: cs,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 날짜 레이블
                        Text(
                          _weekdayShort(stat.dayLocal),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isToday
                                ? cs.primary
                                : isWeekend
                                    ? (stat.dayLocal.weekday == 6
                                        ? Colors.blue.shade400
                                        : Colors.red.shade400)
                                    : cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${stat.dayLocal.day}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday ? cs.primary : cs.onSurfaceVariant,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double ratio;
  final bool isToday;
  final bool isWeekend;
  final ColorScheme cs;

  const _Bar({
    required this.ratio,
    required this.isToday,
    required this.isWeekend,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final barHeight = math.max(4.0, ratio * 90);
    final color = isToday
        ? cs.primary
        : isWeekend
            ? cs.secondary
            : cs.primaryContainer;

    return Container(
      height: barHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withValues(alpha: 0.5),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ]
            : null,
      ),
    );
  }
}
