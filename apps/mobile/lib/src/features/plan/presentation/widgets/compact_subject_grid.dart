import 'package:flutter/material.dart';

import '../../data/custom_subject_store.dart';
import 'plan_subject_chip.dart';

/// 3열·최대 [maxRows]줄 과목 그리드. 넘치면 세로 스크롤.
class CompactSubjectGrid extends StatelessWidget {
  final List<CustomSubject> subjects;
  final String? selectedName;
  final ValueChanged<CustomSubject> onSelect;
  final VoidCallback onAddNew;
  final void Function(CustomSubject subject)? onEdit;
  final Future<void> Function(String name)? onDelete;
  final int maxRows;
  final bool showNewSubjectChip;

  const CompactSubjectGrid({
    super.key,
    required this.subjects,
    required this.selectedName,
    required this.onSelect,
    required this.onAddNew,
    this.onEdit,
    this.onDelete,
    this.maxRows = 2,
    this.showNewSubjectChip = true,
  });

  static const _rowH = 44.0;
  static const _gap = 8.0;

  double get _maxHeight => maxRows * _rowH + (maxRows - 1) * _gap;

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = sortedSubjects();
    final itemCount = sorted.length + (showNewSubjectChip ? 1 : 0);

    return SizedBox(
      height: _maxHeight,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: _gap,
          crossAxisSpacing: _gap,
          childAspectRatio: 2.35,
        ),
        itemCount: itemCount,
        itemBuilder: (context, i) {
          if (showNewSubjectChip && i == itemCount - 1) {
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
          final s = sorted[i];
          final selected = selectedName == s.name;
          if (onEdit != null && onDelete != null) {
            return PlanSubjectChip(
              subject: s,
              selected: selected,
              onTap: () => onSelect(s),
              onEdit: () => onEdit!(s),
              onDelete: () => onDelete!(s.name),
            );
          }
          return _SimpleSubjectChip(
            subject: s,
            selected: selected,
            onTap: () => onSelect(s),
          );
        },
      ),
    );
  }
}

class _SimpleSubjectChip extends StatelessWidget {
  final CustomSubject subject;
  final bool selected;
  final VoidCallback onTap;

  const _SimpleSubjectChip({
    required this.subject,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = subject.color;
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : cs.outlineVariant.withValues(alpha: 0.5),
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(radius: 5, backgroundColor: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? color : cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
