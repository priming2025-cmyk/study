import 'package:flutter/material.dart';

import '../../../plan/data/custom_subject_store.dart';
import '../../../plan/presentation/widgets/compact_subject_grid.dart';
import '../../../plan/presentation/widgets/minute_scroll_picker.dart';
import '../../../plan/data/plan_models.dart';
import 'session_plan_subject_tile.dart';

/// 집중 공부: 오늘 계획(있을 때) + 과목·계획시간 → 하단 [공부 시작].
class SubjectPickerCard extends StatefulWidget {
  final TodayPlan? todayPlan;
  final String? selectedPlanItemId;
  final String? draftSubject;
  final int draftTargetMinutes;
  final int reloadToken;
  final ValueChanged<PlanItem> onSelected;
  final ValueChanged<String> onDraftSubject;
  final ValueChanged<int> onDraftMinutes;
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
    this.reloadToken = 0,
    required this.onSelected,
    required this.onDraftSubject,
    required this.onDraftMinutes,
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

  @override
  void didUpdateWidget(SubjectPickerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _loadSubjects();
    }
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

  Future<void> _editSubject(CustomSubject s) async {
    final ctrl = TextEditingController(text: s.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('과목 이름 수정'),
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
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == s.name || !mounted) {
      return;
    }
    await CustomSubjectStore.rename(s.name, newName, s.colorValue);
    await _loadSubjects();
    if (mounted && widget.draftSubject == s.name) {
      widget.onDraftSubject(newName);
    }
  }

  Future<void> _deleteSubject(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('과목 목록에서 삭제'),
        content: Text('「$name」을(를) 자주 쓰는 과목에서 지울까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await CustomSubjectStore.remove(name);
    await _loadSubjects();
    if (mounted && widget.draftSubject == name) {
      widget.onDraftSubject('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.todayPlan?.items ?? const <PlanItem>[];
    final hasPlan = items.isNotEmpty;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPlan) ...[
          Row(
            children: [
              Text(
                '오늘 계획',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.onOpenAdvancedAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ 계획 추가'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.onReorder != null)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorder: widget.onReorder!,
              itemBuilder: (context, i) {
                final e = items[i];
                return ReorderableDragStartListener(
                  key: ValueKey(e.id),
                  index: i,
                  child: SessionPlanSubjectTile(
                    item: e,
                    selected: e.id == widget.selectedPlanItemId,
                    onTap: () => widget.onSelected(e),
                    onEdit: () => widget.onEditItem(e),
                    onDelete: () => widget.onDeleteItem(e),
                    showDragHandle: true,
                  ),
                );
              },
            )
          else
            ...items.map(
              (e) => SessionPlanSubjectTile(
                item: e,
                selected: e.id == widget.selectedPlanItemId,
                onTap: () => widget.onSelected(e),
                onEdit: () => widget.onEditItem(e),
                onDelete: () => widget.onDeleteItem(e),
              ),
            ),
          const SizedBox(height: 14),
        ],
        Text(
          '과목',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        CompactSubjectGrid(
          subjects: _subjects,
          selectedName: widget.draftSubject,
          onSelect: (s) => widget.onDraftSubject(s.name),
          onAddNew: _promptNewSubject,
          onEdit: _editSubject,
          onDelete: _deleteSubject,
          maxRows: 2,
          pinAddButton: true,
        ),
        const SizedBox(height: 10),
        MinuteScrollPicker(
          sectionLabel: '계획 시간',
          valueMinutes: widget.draftTargetMinutes,
          minMinutes: 5,
          maxMinutes: 240,
          initialStepMinutes: 5,
          isDuration: true,
          compact: true,
          onChanged: widget.onDraftMinutes,
        ),
      ],
    );
  }
}
