import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../../core/providers/core_providers.dart';
import '../data/plan_models.dart';
import '../data/plan_repeat_config.dart';
import 'monthly_plan_overview_sheet.dart';
import 'plan_editor_controller.dart';
import 'widgets/plan_add_item_sheet.dart';
import 'widgets/plan_item_card.dart';
import 'widgets/plan_item_time_sheet.dart';
import 'widgets/plan_time_utils.dart';
import 'widgets/plan_week_bar.dart';

class PlanEditorScreen extends ConsumerStatefulWidget {
  const PlanEditorScreen({super.key});

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  late final PlanEditorController _c;

  @override
  void initState() {
    super.initState();
    _c = PlanEditorController(repo: ref.read(planRepositoryProvider))
      ..addListener(_onChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    try {
      await _c.bootstrap();
    } catch (e) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('불러오기 실패: $e')),
        );
      });
    }
  }

  Future<bool> _confirmDeleteItem(PlanItem item) async {
    final seriesId = item.repeatSeriesId;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 계획을 삭제할까요?'),
        content: Text(
          seriesId == null
              ? '「${item.subject}」 항목이 오늘 계획에서 사라집니다.'
              : '「${item.subject}」은(는) 반복 일정이에요.\n이 항목만 지울까요, 반복 일정 전체를 지울까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('취소'),
          ),
          if (seriesId != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('one'),
              child: const Text('이 항목만'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(seriesId != null ? 'all' : 'one'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(seriesId != null ? '반복 전체 삭제' : '삭제'),
          ),
        ],
      ),
    );
    if (action == null || action == 'cancel' || !mounted) return false;
    try {
      if (action == 'all' && seriesId != null) {
        await _c.deleteRepeatSeries(seriesId);
      } else {
        await _c.deleteItem(item);
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      return false;
    }
  }

  Future<void> _deleteItem(PlanItem item) async {
    await _confirmDeleteItem(item);
  }

  void _openTimeSheet(PlanItem item) {
    PlanItemTimeSheet.show(
      context,
      item: item,
      onSave: ({
        required int targetMinutes,
        required TimeOfDay? startTime,
        required bool reminderEnabled,
      }) =>
          _c.updatePlanEntry(
            item: item,
            subject: item.subject,
            targetMinutes: targetMinutes,
            startTime: startTime,
            reminderEnabled: reminderEnabled,
          ),
    );
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PlanAddItemSheet(
        planDay: _c.planDay,
        existingItems: _c.todayPlan?.items ?? const [],
        onAdd: ({
          required String subject,
          required int targetMinutes,
          TimeOfDay? startTime,
          required bool reminderEnabled,
          PlanRepeatConfig? repeat,
        }) =>
            _c.addPlanEntry(
              subject: subject,
              targetMinutes: targetMinutes,
              startTime: startTime,
              reminderEnabled: reminderEnabled,
              repeat: repeat,
            ),
      ),
    );
  }

  void _openEditSheet(PlanItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PlanAddItemSheet(
        planDay: _c.planDay,
        editItem: item,
        onDelete: () => _confirmDeleteItem(item),
        onAdd: ({
          required String subject,
          required int targetMinutes,
          TimeOfDay? startTime,
          required bool reminderEnabled,
          PlanRepeatConfig? repeat,
        }) =>
            _c.updatePlanEntry(
              item: item,
              subject: subject,
              targetMinutes: targetMinutes,
              startTime: startTime,
              reminderEnabled: reminderEnabled,
            ),
      ),
    );
  }

  void _openMonthlyOverview() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MonthlyPlanOverviewSheet(
        selectedDay: _c.planDay,
        onSelectDay: (day) async {
          await _c.setPlanDayAndReload(day);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _c.todayPlan;
    final completionRate = plan?.completionRate ?? 0.0;
    final items = plan?.items ?? const [];
    final viewingToday = sameCalendarDay(_c.planDay, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('공부 계획'),
        centerTitle: false,
        actions: [
          if (_c.loading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          // 달력 버튼 → 월별 오버뷰
          IconButton(
            tooltip: '월별 계획 보기',
            onPressed: _openMonthlyOverview,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        child: const Icon(Icons.add),
      ),
      body: _c.loading && plan == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_c.showingOfflinePlan)
                        _OfflineBanner(),
                      PlanWeekBar(
                        planDay: _c.planDay,
                        onSelectDay: (d) => _c.setPlanDayAndReload(d),
                        onPrevWeek: () => _c.setPlanDayAndReload(
                          _c.planDay.subtract(const Duration(days: 7)),
                        ),
                        onNextWeek: () => _c.setPlanDayAndReload(
                          _c.planDay.add(const Duration(days: 7)),
                        ),
                        onJumpToday: () =>
                            _c.setPlanDayAndReload(DateTime.now()),
                      ),
                      const SizedBox(height: 4),
                      _ProgressRing(
                        completionRate: completionRate,
                        totalActualSeconds: plan?.totalActualSeconds ?? 0,
                        totalTargetSeconds: plan?.totalTargetSeconds ?? 0,
                        doneCount: items.where((e) => e.focusGoalMet).length,
                        totalCount: items.length,
                      ),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        _EmptyState(
                          onAdd: _openAddSheet,
                          viewingToday: viewingToday,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                          child: Text(
                            '과목 ${items.length}개',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 드래그 순서 변경 가능한 리스트
                if (items.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverReorderableList(
                      itemCount: items.length,
                      onReorder: (oldIndex, newIndex) {
                        _c.reorderItems(oldIndex, newIndex);
                      },
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(item.id),
                          index: i,
                          child: Dismissible(
                            key: ValueKey('dismiss-${item.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                            confirmDismiss: (_) => _confirmDeleteItem(item),
                            child: PlanItemCard(
                              item: item,
                              onEdit: () => _openEditSheet(item),
                              onSchedule: () => _openTimeSheet(item),
                              onDelete: () => _deleteItem(item),
                              showDragHandle: items.length > 1,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
// 오프라인 배너
// ─────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 18,
              color: cs.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '연결이 불안정해요. 마지막 저장 계획을 보여드려요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSecondaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 링 게이지 진행률 카드
// ─────────────────────────────────────────────
class _ProgressRing extends StatelessWidget {
  final double completionRate;
  final int totalActualSeconds;
  final int totalTargetSeconds;
  final int doneCount;
  final int totalCount;

  const _ProgressRing({
    required this.completionRate,
    required this.totalActualSeconds,
    required this.totalTargetSeconds,
    required this.doneCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pct = (completionRate * 100).round();
    final actualMin = (totalActualSeconds / 60).round();
    final targetMin = (totalTargetSeconds / 60).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CustomPaint(
              painter: _RingPainter(
                progress: completionRate,
                color: cs.primary,
                background: cs.surfaceContainerHigh,
              ),
              child: Center(
                child: Text(
                  '$pct%',
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '공부 ${formatPlanMinutes(actualMin)} / 목표 ${targetMin > 0 ? formatPlanMinutes(targetMin) : '—'}',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  totalCount > 0 ? '집중 달성 $doneCount/$totalCount과목' : '과목을 추가해 보세요',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color background;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 5.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────
// 빈 상태
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final bool viewingToday;

  const _EmptyState({required this.onAdd, required this.viewingToday});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.edit_calendar_outlined,
              size: 52, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            '과목을 추가해 보세요',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 20),
          FloatingActionButton.small(
            onPressed: onAdd,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
