import 'package:flutter/material.dart';

import '../../data/custom_subject_store.dart';
import 'plan_subject_chip.dart';

/// 과목 3열 그리드.
///
/// [maxRows]가 null이면 전체 나열(계획 탭).
/// [maxRows]가 있으면 해당 줄 수만 보이고 스크롤(공부 탭), [pinAddButton] 시 새과목은 항상 아래 고정.
class CompactSubjectGrid extends StatelessWidget {
  final List<CustomSubject> subjects;
  final String? selectedName;
  final ValueChanged<CustomSubject> onSelect;
  final VoidCallback onAddNew;
  final void Function(CustomSubject subject)? onEdit;
  final Future<void> Function(String name)? onDelete;

  /// null = 높이 제한 없이 전체 표시.
  final int? maxRows;

  /// true면 스크롤 영역 밖에 「새과목」 버튼 고정.
  final bool pinAddButton;

  const CompactSubjectGrid({
    super.key,
    required this.subjects,
    required this.selectedName,
    required this.onSelect,
    required this.onAddNew,
    this.onEdit,
    this.onDelete,
    this.maxRows,
    this.pinAddButton = false,
  });

  static const _rowH = 44.0;
  static const _gap = 8.0;

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    mainAxisSpacing: _gap,
    crossAxisSpacing: _gap,
    childAspectRatio: 2.35,
  );

  double? get _scrollHeight {
    if (maxRows == null) return null;
    return maxRows! * _rowH + (maxRows! - 1) * _gap;
  }

  List<CustomSubject> sortedSubjects() {
    final defaultNames = defaultSubjects.map((s) => s.name).toList();
    final byName = {for (final s in subjects) s.name: s};
    final ordered = <CustomSubject>[];
    for (final name in defaultNames) {
      final s = byName.remove(name);
      if (s != null) ordered.add(s);
    }
    final rest = byName.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return [...ordered, ...rest];
  }

  Widget _newSubjectChip(ColorScheme cs) {
    return Material(
      color: cs.primaryContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onAddNew,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 4),
              Text(
                '새과목',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subjectCell(CustomSubject s, bool selected) {
    return PlanSubjectChip(
      subject: s,
      selected: selected,
      onTap: () => onSelect(s),
      onEdit: () => onEdit?.call(s),
      onDelete: () => onDelete?.call(s.name) ?? Future.value(),
    );
  }

  Widget _buildGrid({
    required List<CustomSubject> sorted,
    required int itemCount,
    required bool Function(int index) isAddSlot,
    required ScrollPhysics physics,
    required bool shrinkWrap,
  }) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: _gridDelegate,
      itemCount: itemCount,
      itemBuilder: (context, i) {
        if (isAddSlot(i)) {
          return _newSubjectChip(Theme.of(context).colorScheme);
        }
        final s = sorted[i];
        return _subjectCell(s, selectedName == s.name);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = sortedSubjects();
    final usePinnedAdd = pinAddButton && maxRows != null;
    final subjectOnly = usePinnedAdd;
    final itemCount =
        sorted.length + (subjectOnly ? 0 : 1);
    final scrollH = _scrollHeight;

    if (maxRows == null) {
      return _buildGrid(
        sorted: sorted,
        itemCount: itemCount,
        isAddSlot: (i) => i == itemCount - 1,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
      );
    }

    final grid = _buildGrid(
      sorted: sorted,
      itemCount: subjectOnly ? sorted.length : itemCount,
      isAddSlot: (i) => !subjectOnly && i == itemCount - 1,
      physics: const ClampingScrollPhysics(),
      shrinkWrap: false,
    );

    if (!usePinnedAdd) {
      return SizedBox(height: scrollH, child: grid);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: scrollH, child: grid),
        const SizedBox(height: 6),
        SizedBox(
          height: _rowH,
          child: _newSubjectChip(cs),
        ),
      ],
    );
  }
}
