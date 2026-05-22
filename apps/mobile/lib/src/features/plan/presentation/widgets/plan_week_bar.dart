import 'package:flutter/material.dart';

/// [day]가 속한 주의 월요일 00:00 (로컬 달력).
DateTime planMondayOf(DateTime day) {
  final c = DateTime(day.year, day.month, day.day);
  return c.subtract(Duration(days: c.weekday - DateTime.monday));
}

bool sameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 한 주(월~일) — 좌우 작은 화살표로 주 이동, 설명 텍스트 없음.
class PlanWeekBar extends StatelessWidget {
  final DateTime planDay;
  final Future<void> Function(DateTime day) onSelectDay;
  final Future<void> Function() onPrevWeek;
  final Future<void> Function() onNextWeek;
  final VoidCallback onJumpToday;
  final bool showJumpToday;

  const PlanWeekBar({
    super.key,
    required this.planDay,
    required this.onSelectDay,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onJumpToday,
    this.showJumpToday = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final monday = planMondayOf(planDay);
    const weekDays = ['월', '화', '수', '목', '금', '토', '일'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          _WeekArrow(
            icon: Icons.chevron_left_rounded,
            onTap: () => onPrevWeek(),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v > 280) onPrevWeek();
                if (v < -280) onNextWeek();
              },
              child: Row(
                children: List.generate(7, (i) {
                  final day = monday.add(Duration(days: i));
                  final isSelected = sameCalendarDay(day, planDay);
                  final isToday = sameCalendarDay(day, today);
                  final isWeekend = i >= 5;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onSelectDay(day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary
                              : isToday
                                  ? cs.primaryContainer.withValues(alpha: 0.5)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              weekDays[i],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? cs.onPrimary
                                    : isWeekend
                                        ? (i == 6
                                            ? Colors.red.shade400
                                            : Colors.blue.shade400)
                                        : cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? cs.onPrimary
                                    : isToday
                                        ? cs.primary
                                        : cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          _WeekArrow(
            icon: Icons.chevron_right_rounded,
            onTap: () => onNextWeek(),
          ),
        ],
      ),
    );
  }
}

class _WeekArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _WeekArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
