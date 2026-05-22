import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/plan_models.dart';
import 'plan_time_utils.dart';
import 'subject_preset_picker.dart';

class PlanItemCard extends StatelessWidget {
  final PlanItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onDoneChanged;
  final bool showDragHandle;

  const PlanItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onDoneChanged,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final targetMin = (item.targetSeconds / 60).round();
    final actualMin = (item.actualSeconds / 60).round();
    final rate = item.completionRate.clamp(0.0, 1.0);
    final color = subjectColor(item.subject);
    final isDone = item.isDone;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        borderRadius: BorderRadius.circular(14),
        color: cs.surface,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDone
                  ? cs.outlineVariant.withValues(alpha: 0.5)
                  : color.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isDone ? cs.outline : color,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.subject,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                          color: isDone ? cs.onSurfaceVariant : cs.onSurface,
                        ),
                      ),
                    ),
                    Checkbox(
                      value: isDone,
                      activeColor: color,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => onDoneChanged(v ?? false),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                    ),
                    if (showDragHandle)
                      Icon(Icons.drag_handle_rounded,
                          size: 18,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                  ],
                ),
              ),
              if (item.scheduledStartAt != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      DateFormat('HH:mm', 'ko')
                          .format(item.scheduledStartAt!.toLocal()),
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Text(
                      '${formatPlanMinutes(actualMin)}/${formatPlanMinutes(targetMin)}',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDone ? cs.onSurfaceVariant : color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: rate,
                          minHeight: 5,
                          color: isDone ? cs.outline : color,
                          backgroundColor: color.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(rate * 100).round()}%',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
