import 'package:flutter/material.dart';

import '../../data/custom_subject_store.dart';

/// 과목 선택 칩 — 휴지통으로 목록에서 삭제.
class PlanSubjectChip extends StatelessWidget {
  final CustomSubject subject;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const PlanSubjectChip({
    super.key,
    required this.subject,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = subject.color;

    return Material(
      color: selected ? color.withValues(alpha: 0.14) : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : cs.outlineVariant.withValues(alpha: 0.5),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 7, backgroundColor: color),
              const SizedBox(width: 8),
              Text(
                subject.name,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : cs.onSurface,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
