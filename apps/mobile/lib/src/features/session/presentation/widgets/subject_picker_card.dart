import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../plan/data/plan_models.dart';
import '../../../plan/presentation/widgets/subject_preset_picker.dart';
import 'session_plan_subject_tile.dart';

/// 집중 세션에서 오늘 과목을 고르거나 퀵스타트로 즉시 시작합니다.
class SubjectPickerCard extends StatefulWidget {
  final TodayPlan? todayPlan;
  final String? selectedPlanItemId;
  final ValueChanged<PlanItem> onSelected;
  final List<String> recentSubjects;
  final Future<void> Function({
    required String subject,
    required int targetMinutes,
  }) onQuickAdd;
  final VoidCallback onOpenAdvancedAdd;
  final void Function(PlanItem item) onEditItem;
  final Future<void> Function(PlanItem item) onDeleteItem;
  final void Function(int oldIndex, int newIndex)? onReorder;

  const SubjectPickerCard({
    super.key,
    required this.todayPlan,
    required this.selectedPlanItemId,
    required this.onSelected,
    required this.recentSubjects,
    required this.onQuickAdd,
    required this.onOpenAdvancedAdd,
    required this.onEditItem,
    required this.onDeleteItem,
    this.onReorder,
  });

  @override
  State<SubjectPickerCard> createState() => _SubjectPickerCardState();
}

class _SubjectPickerCardState extends State<SubjectPickerCard> {
  String? _quickSubject;
  int _quickMinutes = 60;
  bool _adding = false;

  static const _timeOptions = [
    (label: '30분', minutes: 30),
    (label: '1시간', minutes: 60),
    (label: '1.5시간', minutes: 90),
    (label: '2시간', minutes: 120),
    (label: '3시간', minutes: 180),
  ];

  static const _quickSubjects = ['국어', '영어', '수학', '과학', '사회', '역사'];

  Future<void> _submitQuickAdd() async {
    final subject = _quickSubject;
    if (subject == null || subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('과목을 선택해 주세요')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _adding = true);
    try {
      await widget.onQuickAdd(subject: subject, targetMinutes: _quickMinutes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추가 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.todayPlan?.items ?? const <PlanItem>[];
    final hasPlan = items.isNotEmpty;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (hasPlan) {
      return _PlanSection(
        items: items,
        selectedPlanItemId: widget.selectedPlanItemId,
        onSelected: widget.onSelected,
        onEditItem: widget.onEditItem,
        onDeleteItem: widget.onDeleteItem,
        onReorder: widget.onReorder,
        onOpenAdvancedAdd: widget.onOpenAdvancedAdd,
        cs: cs,
        tt: tt,
      );
    }

    return _QuickStartSection(
      quickSubject: _quickSubject,
      quickMinutes: _quickMinutes,
      recentSubjects: widget.recentSubjects,
      adding: _adding,
      onSelectSubject: (s) => setState(() => _quickSubject = s),
      onSelectMinutes: (m) => setState(() => _quickMinutes = m),
      onStart: _submitQuickAdd,
      onOpenAdvancedAdd: widget.onOpenAdvancedAdd,
      timeOptions: _timeOptions,
      quickSubjects: _quickSubjects,
      cs: cs,
      tt: tt,
    );
  }
}

class _PlanSection extends StatelessWidget {
  final List<PlanItem> items;
  final String? selectedPlanItemId;
  final ValueChanged<PlanItem> onSelected;
  final void Function(PlanItem) onEditItem;
  final Future<void> Function(PlanItem) onDeleteItem;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final VoidCallback onOpenAdvancedAdd;
  final ColorScheme cs;
  final TextTheme tt;

  const _PlanSection({
    required this.items,
    required this.selectedPlanItemId,
    required this.onSelected,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onReorder,
    required this.onOpenAdvancedAdd,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final metCount = items.where((e) => e.focusGoalMet).length;
    final totalCount = items.length;
    final allMet = metCount == totalCount && totalCount > 0;
    final canReorder = onReorder != null && items.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allMet ? '오늘 목표 달성! 🎉' : '오늘의 계획',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: allMet ? cs.primary : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      allMet
                          ? '추가로 공부할 과목을 선택하거나 새 과목을 추가해 보세요.'
                          : '과목을 탭하면 바로 공부를 시작해요',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onOpenAdvancedAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('추가'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        if (totalCount > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: metCount / totalCount,
              minHeight: 5,
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '집중 달성 $metCount/$totalCount',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.end,
          ),
          const SizedBox(height: 10),
        ],
        if (canReorder)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            onReorder: onReorder!,
            itemBuilder: (context, i) {
              final e = items[i];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(e.id),
                index: i,
                child: SessionPlanSubjectTile(
                  item: e,
                  selected: e.id == selectedPlanItemId,
                  onTap: () => onSelected(e),
                  onEdit: () => onEditItem(e),
                  onDelete: () => onDeleteItem(e),
                  showDragHandle: true,
                ),
              );
            },
          )
        else
          ...items.map(
            (e) => SessionPlanSubjectTile(
              item: e,
              selected: e.id == selectedPlanItemId,
              onTap: () => onSelected(e),
              onEdit: () => onEditItem(e),
              onDelete: () => onDeleteItem(e),
            ),
          ),
      ],
    );
  }
}

class _QuickStartSection extends StatelessWidget {
  final String? quickSubject;
  final int quickMinutes;
  final List<String> recentSubjects;
  final bool adding;
  final ValueChanged<String> onSelectSubject;
  final ValueChanged<int> onSelectMinutes;
  final VoidCallback onStart;
  final VoidCallback onOpenAdvancedAdd;
  final List<({String label, int minutes})> timeOptions;
  final List<String> quickSubjects;
  final ColorScheme cs;
  final TextTheme tt;

  const _QuickStartSection({
    required this.quickSubject,
    required this.quickMinutes,
    required this.recentSubjects,
    required this.adding,
    required this.onSelectSubject,
    required this.onSelectMinutes,
    required this.onStart,
    required this.onOpenAdvancedAdd,
    required this.timeOptions,
    required this.quickSubjects,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final allSubjects = [
      ...quickSubjects,
      ...recentSubjects.where((s) => !quickSubjects.contains(s)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '지금 바로 시작',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '과목과 시간을 선택하고 시작 버튼을 누르세요',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        _StepLabel(step: '1', label: '과목 선택', cs: cs, tt: tt),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allSubjects.map((s) {
            final isSelected = quickSubject == s;
            final color = subjectColor(s);
            return ChoiceChip(
              label: Text(s),
              selected: isSelected,
              selectedColor: color.withValues(alpha: 0.18),
              checkmarkColor: color,
              labelStyle: TextStyle(
                color: isSelected ? color : cs.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected ? color : cs.outlineVariant,
                width: isSelected ? 1.5 : 1,
              ),
              backgroundColor: cs.surfaceContainerLowest,
              onSelected: (_) => onSelectSubject(s),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _StepLabel(step: '2', label: '공부 시간', cs: cs, tt: tt),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: timeOptions.map((opt) {
            final isSelected = quickMinutes == opt.minutes;
            return ChoiceChip(
              label: Text(opt.label),
              selected: isSelected,
              onSelected: (_) => onSelectMinutes(opt.minutes),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: adding || quickSubject == null ? null : onStart,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: adding
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
              : const Icon(Icons.play_arrow_rounded, size: 24),
          label: Text(
            adding ? '추가 중…' : '공부 시작',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: onOpenAdvancedAdd,
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('시작 시각·반복 설정'),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepLabel extends StatelessWidget {
  final String step;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  const _StepLabel({
    required this.step,
    required this.label,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: tt.labelSmall?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: tt.labelLarge),
      ],
    );
  }
}
