import 'package:flutter/material.dart';

import '../../../plan/data/custom_subject_store.dart';
import '../../../plan/presentation/widgets/compact_subject_grid.dart';
import '../../../plan/presentation/widgets/minute_scroll_picker.dart';
import '../../../plan/data/plan_models.dart';
import 'session_plan_subject_tile.dart';

/// 집중 세션에서 오늘 과목을 고르거나 과목·계획시간을 정한 뒤 하단 [공부 시작]으로 이어갑니다.
class SubjectPickerCard extends StatefulWidget {
  final TodayPlan? todayPlan;
  final String? selectedPlanItemId;
  final String? draftSubject;
  final int draftTargetMinutes;
  final ValueChanged<PlanItem> onSelected;
  final ValueChanged<String> onDraftSubject;
  final ValueChanged<int> onDraftMinutes;
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
    required this.draftSubject,
    required this.draftTargetMinutes,
    required this.onSelected,
    required this.onDraftSubject,
    required this.onDraftMinutes,
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
  List<CustomSubject> _subjects = List.from(defaultSubjects);

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final list = await CustomSubjectStore.load();
    if (mounted) setState(() => _subjects = list);
  }

  Future<void> _promptNewSubject() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 과목'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '과목 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await CustomSubjectStore.upsert(name, 0xFF3B82F6);
    await _loadSubjects();
    if (mounted) widget.onDraftSubject(name);
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

    return _EmptyPlanSetup(
      subjects: _subjects,
      selectedName: widget.draftSubject,
      targetMinutes: widget.draftTargetMinutes,
      onSelectSubject: widget.onDraftSubject,
      onSelectMinutes: widget.onDraftMinutes,
      onAddNewSubject: _promptNewSubject,
      onOpenAdvancedAdd: widget.onOpenAdvancedAdd,
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
  final Future<void> Function(PlanItem item) onDeleteItem;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '오늘 계획',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (onReorder != null)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorder: onReorder!,
            itemBuilder: (context, i) {
              final e = items[i];
              return ReorderableDragStartListener(
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
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onOpenAdvancedAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('계획 추가'),
          ),
        ),
      ],
    );
  }
}

class _EmptyPlanSetup extends StatelessWidget {
  final List<CustomSubject> subjects;
  final String? selectedName;
  final int targetMinutes;
  final ValueChanged<String> onSelectSubject;
  final ValueChanged<int> onSelectMinutes;
  final VoidCallback onAddNewSubject;
  final VoidCallback onOpenAdvancedAdd;
  final ColorScheme cs;
  final TextTheme tt;

  const _EmptyPlanSetup({
    required this.subjects,
    required this.selectedName,
    required this.targetMinutes,
    required this.onSelectSubject,
    required this.onSelectMinutes,
    required this.onAddNewSubject,
    required this.onOpenAdvancedAdd,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '과목',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        CompactSubjectGrid(
          subjects: subjects,
          selectedName: selectedName,
          onSelect: (s) => onSelectSubject(s.name),
          onAddNew: onAddNewSubject,
          maxRows: 2,
        ),
        const SizedBox(height: 10),
        MinuteScrollPicker(
          sectionLabel: '계획 시간',
          valueMinutes: targetMinutes,
          minMinutes: 5,
          maxMinutes: 240,
          initialStepMinutes: 5,
          isDuration: true,
          compact: true,
          onChanged: onSelectMinutes,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onOpenAdvancedAdd,
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('시작 시각·반복 설정'),
          ),
        ),
      ],
    );
  }
}
