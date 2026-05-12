import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// [day]가 속한 주의 월요일 00:00 (로컬 달력).
DateTime planMondayOf(DateTime day) {
  final c = DateTime(day.year, day.month, day.day);
  return c.subtract(Duration(days: c.weekday - DateTime.monday));
}

bool sameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 한 주(월~일)를 보여 주고, **이전/다음 주**로 넓게 이동할 수 있는 바.
/// 좌우 **스와이프**로도 주를 바꿀 수 있어 줌인/줌아웃에 가까운 탐색감을 줍니다.
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

  String _weekRangeLabel(DateTime monday) {
    final end = monday.add(const Duration(days: 6));
    if (monday.year == end.year && monday.month == end.month) {
      return '${monday.year}년 ${monday.month}월 ${monday.day}일–${end.day}일';
    }
    final a = DateFormat.yMd('ko').format(monday);
    final b = DateFormat.yMd('ko').format(end);
    return '$a – $b';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final today = DateTime.now();
    final monday = planMondayOf(planDay);
    const weekDays = ['월', '화', '수', '목', '금', '토', '일'];
    final viewingToday = sameCalendarDay(planDay, today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: '이전 주',
                onPressed: () => onPrevWeek(),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _weekRangeLabel(monday),
                      textAlign: TextAlign.center,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '한 주 단위로 이동 · 좌우로 밀어서 바꿀 수 있어요',
                      textAlign: TextAlign.center,
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '다음 주',
                onPressed: () => onNextWeek(),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        if (showJumpToday && !viewingToday)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 2),
              child: TextButton.icon(
                onPressed: onJumpToday,
                icon: const Icon(Icons.today_outlined, size: 18),
                label: const Text('오늘로'),
              ),
            ),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v > 280) {
              onPrevWeek();
            } else if (v < -280) {
              onNextWeek();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primary
                            : isToday
                                ? cs.primaryContainer
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            weekDays[i],
                            style: TextStyle(
                              fontSize: 11,
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
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? cs.onPrimary
                                  : isToday
                                      ? cs.primary
                                      : cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isToday && !isSelected
                                  ? cs.primary
                                  : Colors.transparent,
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
      ],
    );
  }
}
