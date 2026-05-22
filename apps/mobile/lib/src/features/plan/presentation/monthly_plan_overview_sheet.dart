import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import 'widgets/plan_time_utils.dart';

/// 월별 계획 핵심 오버뷰 바텀시트.
/// 이번 달 달력 그리드를 보여주고, 계획이 있는 날은 점 표시 + 탭하면 해당 날짜로 이동.
class MonthlyPlanOverviewSheet extends ConsumerStatefulWidget {
  final DateTime selectedDay;
  final Future<void> Function(DateTime day) onSelectDay;

  const MonthlyPlanOverviewSheet({
    super.key,
    required this.selectedDay,
    required this.onSelectDay,
  });

  @override
  ConsumerState<MonthlyPlanOverviewSheet> createState() =>
      _MonthlyPlanOverviewSheetState();
}

class _MonthlyPlanOverviewSheetState
    extends ConsumerState<MonthlyPlanOverviewSheet> {
  late DateTime _viewMonth;
  // 날짜별 계획 요약: key=날짜(yyyy-MM-dd), value={count, targetMinutes}
  Map<String, _DaySummary> _summaries = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _viewMonth = DateTime(widget.selectedDay.year, widget.selectedDay.month);
    _loadMonth(_viewMonth);
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadMonth(DateTime month) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(planRepositoryProvider);
      final first = DateTime(month.year, month.month, 1);
      final last = DateTime(month.year, month.month + 1, 0);
      final summaries = <String, _DaySummary>{};
      // 해당 월의 각 날짜에 대해 계획 로드 (캐시 우선)
      for (var d = first;
          !d.isAfter(last);
          d = d.add(const Duration(days: 1))) {
        final plan = await repo.loadCachedPlanForDate(d) ??
            await repo.fetchPlanForDate(d);
        if (plan != null && plan.items.isNotEmpty) {
          summaries[_dateKey(d)] = _DaySummary(
            count: plan.items.length,
            targetMinutes: (plan.totalTargetSeconds / 60).round(),
            doneCount: plan.items.where((e) => e.isDone).length,
            subjects: plan.items.map((e) => e.subject).toList(),
            completionRate: plan.completionRate,
          );
        }
      }
      if (mounted) {
        setState(() {
          _summaries = summaries;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    final prev = DateTime(_viewMonth.year, _viewMonth.month - 1);
    setState(() => _viewMonth = prev);
    _loadMonth(prev);
  }

  void _nextMonth() {
    final next = DateTime(_viewMonth.year, _viewMonth.month + 1);
    setState(() => _viewMonth = next);
    _loadMonth(next);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final today = DateTime.now();

    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth =
        DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    // 첫 날의 요일(월=1, 일=7 → 0-indexed: 월=0)
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              // 월 네비게이션
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _prevMonth,
                      icon: const Icon(Icons.chevron_left),
                      tooltip: '이전 달',
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('yyyy년 M월', 'ko').format(_viewMonth),
                        textAlign: TextAlign.center,
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: _nextMonth,
                      icon: const Icon(Icons.chevron_right),
                      tooltip: '다음 달',
                    ),
                  ],
                ),
              ),
              // 요일 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: ['월', '화', '수', '목', '금', '토', '일']
                      .asMap()
                      .entries
                      .map((e) => Expanded(
                            child: Center(
                              child: Text(
                                e.value,
                                style: tt.labelSmall?.copyWith(
                                  color: e.key == 5
                                      ? Colors.blue.shade400
                                      : e.key == 6
                                          ? Colors.red.shade400
                                          : cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 4),
              // 달력 그리드
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      ...List.generate(rows, (row) {
                        return Row(
                          children: List.generate(7, (col) {
                            final cellIndex = row * 7 + col;
                            final dayNum = cellIndex - startOffset + 1;
                            if (dayNum < 1 || dayNum > daysInMonth) {
                              return const Expanded(child: SizedBox(height: 52));
                            }
                            final date = DateTime(
                                _viewMonth.year, _viewMonth.month, dayNum);
                            final key = _dateKey(date);
                            final summary = _summaries[key];
                            final isToday = date.year == today.year &&
                                date.month == today.month &&
                                date.day == today.day;
                            final isSelected =
                                date.year == widget.selectedDay.year &&
                                    date.month == widget.selectedDay.month &&
                                    date.day == widget.selectedDay.day;
                            final isWeekend = col >= 5;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  await widget.onSelectDay(date);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.all(2),
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: _cellBackground(
                                      cs: cs,
                                      summary: summary,
                                      isSelected: isSelected,
                                      isToday: isToday,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected
                                        ? Border.all(color: cs.primary, width: 1.5)
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$dayNum',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? cs.onPrimary
                                              : isToday
                                                  ? cs.primary
                                                  : isWeekend
                                                      ? (col == 5
                                                          ? Colors.blue.shade400
                                                          : Colors.red.shade400)
                                                      : cs.onSurface,
                                        ),
                                      ),
                                      if (summary != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          subjectsAbbrevLine(summary.subjects),
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? cs.onPrimary.withValues(alpha: 0.85)
                                                : cs.onSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        _CompletionMiniBar(
                                          rate: summary.completionRate,
                                          isSelected: isSelected,
                                          cs: cs,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      }),
                      const SizedBox(height: 16),
                      // 범례
                      _Legend(cs: cs, tt: tt),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DaySummary {
  final int count;
  final int targetMinutes;
  final int doneCount;
  final List<String> subjects;
  final double completionRate;

  const _DaySummary({
    required this.count,
    required this.targetMinutes,
    required this.doneCount,
    required this.subjects,
    required this.completionRate,
  });

  bool get allDone => doneCount == count && count > 0;
}

Color _cellBackground({
  required ColorScheme cs,
  required _DaySummary? summary,
  required bool isSelected,
  required bool isToday,
}) {
  if (isSelected) return cs.primary;
  if (summary == null) {
    return isToday ? cs.primaryContainer.withValues(alpha: 0.35) : Colors.transparent;
  }
  final rate = summary.completionRate;
  if (summary.allDone) return Colors.green.shade50;
  if (rate > 0) {
    return Color.lerp(
      cs.surfaceContainerHigh,
      cs.primaryContainer,
      rate.clamp(0.0, 1.0),
    )!;
  }
  return cs.surfaceContainerHigh;
}

class _CompletionMiniBar extends StatelessWidget {
  final double rate;
  final bool isSelected;
  final ColorScheme cs;

  const _CompletionMiniBar({
    required this.rate,
    required this.isSelected,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: rate.clamp(0.0, 1.0),
          minHeight: 3,
          backgroundColor: isSelected
              ? cs.onPrimary.withValues(alpha: 0.25)
              : cs.outlineVariant.withValues(alpha: 0.4),
          color: isSelected
              ? cs.onPrimary
              : rate >= 1
                  ? Colors.green.shade400
                  : cs.primary,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;

  const _Legend({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendItem(
            color: cs.surfaceContainerHigh,
            label: '계획 있음',
            cs: cs,
            tt: tt,
          ),
          const SizedBox(width: 16),
          _LegendItem(
            color: Colors.green.shade400,
            label: '모두 완료',
            cs: cs,
            tt: tt,
          ),
          const SizedBox(width: 16),
          _LegendItem(
            color: cs.primary,
            label: '선택됨',
            cs: cs,
            tt: tt,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: cs.outlineVariant, width: 0.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
