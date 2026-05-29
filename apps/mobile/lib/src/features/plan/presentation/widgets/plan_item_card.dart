import 'package:flutter/material.dart';

import '../../data/plan_models.dart';
import 'plan_time_utils.dart';
import 'subject_preset_picker.dart';

class PlanItemCard extends StatelessWidget {
  final PlanItem item;
  final VoidCallback onEdit;
  final VoidCallback onSchedule;
  final VoidCallback onDelete;
  final VoidCallback? onStartStudy;
  final bool showDragHandle;

  const PlanItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onSchedule,
    required this.onDelete,
    this.onStartStudy,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final rate = item.completionRate.clamp(0.0, 1.0);
    final color = subjectColor(item.subject);
    final met = item.focusGoalMet;
    final timeRange = formatPlanTimeRange(item);
    final pct = planFocusPercent(item);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        borderRadius: BorderRadius.circular(14),
        color: cs.surface,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: met
                  ? color.withValues(alpha: 0.45)
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
                        color: met ? color : color.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            item.subject,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '시간 설정',
                      icon: Icon(
                        Icons.access_time_rounded,
                        size: 20,
                        color: item.scheduledStartAt != null
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: onSchedule,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: onEdit,
                    ),
                    IconButton(
                      tooltip: '오늘 계획에서 삭제',
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: cs.error.withValues(alpha: 0.85)),
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                    ),
                    if (showDragHandle)
                      Icon(
                        Icons.drag_handle_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Text(
                      timeRange,
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: met
                            ? color.withValues(alpha: 0.15)
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        met ? '100%' : '$pct%',
                        style: tt.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: met ? color : cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: rate,
                          minHeight: 5,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onStartStudy != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: FilledButton.tonalIcon(
                    onPressed: onStartStudy,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('집중공부 시작'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
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
