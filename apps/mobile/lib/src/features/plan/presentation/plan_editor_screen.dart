import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../../core/providers/core_providers.dart';
import '../data/plan_models.dart';
import 'plan_editor_controller.dart';
import 'widgets/plan_item_card.dart';
import 'widgets/plan_add_item_sheet.dart';
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

  Future<void> _deleteItem(PlanItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 과목을 삭제할까요?'),
        content: Text('「${item.subject}」 항목이 계획에서 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _c.deleteItem(item);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  Future<void> _toggleDone(PlanItem item, bool done) async {
    try {
      await _c.toggleDone(item, done);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('업데이트 실패: $e')));
    }
  }

  Future<void> _setActualMinutes(PlanItem item, int minutes) async {
    try {
      await _c.setActualMinutes(item, minutes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('실제시간 저장 실패: $e')));
    }
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PlanAddItemSheet(
        planDay: _c.planDay,
        recentSubjects: _c.recentSubjects,
        onAdd: ({
          required String subject,
          required int targetMinutes,
          TimeOfDay? startTime,
          required bool reminderEnabled,
        }) =>
            _c.addPlanEntry(
              subject: subject,
              targetMinutes: targetMinutes,
              startTime: startTime,
              reminderEnabled: reminderEnabled,
            ),
      ),
    );
  }

  void _openEditSheet(PlanItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PlanAddItemSheet(
        planDay: _c.planDay,
        editItem: item,
        recentSubjects: _c.recentSubjects,
        onAdd: ({
          required String subject,
          required int targetMinutes,
          TimeOfDay? startTime,
          required bool reminderEnabled,
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

  @override
  Widget build(BuildContext context) {
    final plan = _c.todayPlan;
    final completionRate = plan?.completionRate ?? 0.0;
    final items = plan?.items ?? const [];

    final viewingToday = sameCalendarDay(_c.planDay, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(viewingToday ? '오늘의 계획' : '계획'),
        centerTitle: false,
        actions: [
          if (_c.loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('과목 추가'),
      ),
      body: _c.loading && plan == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 오프라인 배너
                      if (_c.showingOfflinePlan)
                        _OfflineBanner(),
                      // 주간 날짜 바 (이전/다음 주 · 스와이프 · 오늘로)
                      PlanWeekBar(
                        planDay: _c.planDay,
                        onSelectDay: (d) => _c.setPlanDayAndReload(d),
                        onPrevWeek: () => _c.setPlanDayAndReload(
                          _c.planDay.subtract(const Duration(days: 7)),
                        ),
                        onNextWeek: () => _c.setPlanDayAndReload(
                          _c.planDay.add(const Duration(days: 7)),
                        ),
                        onJumpToday: () => _c.setPlanDayAndReload(DateTime.now()),
                      ),
                      const SizedBox(height: 4),
                      // 링 진행률 + 요약
                      _ProgressRing(
                        completionRate: completionRate,
                        totalActualSeconds: plan?.totalActualSeconds ?? 0,
                        totalTargetSeconds: plan?.totalTargetSeconds ?? 0,
                        doneCount: items.where((e) => e.isDone).length,
                        totalCount: items.length,
                      ),
                      const SizedBox(height: 16),
                      if (items.isEmpty)
                        _EmptyState(
                          onAdd: _openAddSheet,
                          viewingToday: viewingToday,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
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
                              const SizedBox(height: 4),
                              Text(
                                '체크: 완료 표시 · 연필: 과목·목표·알림 수정 · 휴지통: 삭제',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final item = items[i];
                        return PlanItemCard(
                          item: item,
                          onEdit: () => _openEditSheet(item),
                          onDelete: () => _deleteItem(item),
                          onDoneChanged: (v) => _toggleDone(item, v),
                          onActualMinutesChanged: (m) =>
                              _setActualMinutes(item, m),
                        );
                      },
                      childCount: items.length,
                    ),
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

  String _fmt(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pct = (completionRate * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            // 링
            SizedBox(
              width: 88,
              height: 88,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: completionRate,
                  color: cs.primary,
                  background: cs.surfaceContainerHigh,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$pct%',
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                      Text(
                        '달성',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatRow(
                    icon: Icons.check_circle_outline,
                    label: '완료한 과목',
                    value: '$doneCount / $totalCount개',
                    color: cs.secondary,
                  ),
                  const SizedBox(height: 10),
                  _StatRow(
                    icon: Icons.timer_outlined,
                    label: '실제 공부',
                    value: _fmt(totalActualSeconds),
                    color: cs.primary,
                  ),
                  const SizedBox(height: 10),
                  _StatRow(
                    icon: Icons.flag_outlined,
                    label: '목표 시간',
                    value: totalTargetSeconds > 0
                        ? _fmt(totalTargetSeconds)
                        : '계획 없음',
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
        ),
        Text(value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                )),
      ],
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
    const strokeWidth = 8.0;
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
            viewingToday ? '오늘의 계획을 세워보세요' : '이 날짜의 계획을 세워보세요',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            viewingToday
                ? '과목과 목표 시간을 추가하면\n달성률을 실시간으로 확인할 수 있어요.'
                : '위에서 주를 바꿔 다른 날도 미리 계획할 수 있어요.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('첫 과목 추가하기'),
          ),
        ],
      ),
    );
  }
}
