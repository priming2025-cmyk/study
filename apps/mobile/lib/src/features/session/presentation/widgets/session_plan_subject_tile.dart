import 'package:flutter/material.dart';

import '../../../plan/data/plan_models.dart';
import '../../../plan/presentation/widgets/plan_time_utils.dart';
import '../../../plan/presentation/widgets/subject_preset_picker.dart';

/// 집중 세션 — 과목 카드 (탭=선택, 연필·휴지통·드래그).
class SessionPlanSubjectTile extends StatelessWidget {
  final PlanItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showDragHandle;

  const SessionPlanSubjectTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = subjectColor(item.subject);
    final timeRange = formatPlanTimeRange(item);
    final pct = planFocusPercent(item);
    final met = item.focusGoalMet;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? color.withValues(alpha: 0.1) : cs.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? color
                    : cs.outlineVariant.withValues(alpha: 0.6),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.subject,
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              timeRange,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            met ? '100%' : '$pct%',
                            style: tt.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: met ? color : cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: item.completionRate.clamp(0.0, 1.0),
                          minHeight: 4,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '편집',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: '삭제',
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: cs.onSurfaceVariant),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
                if (showDragHandle)
                  Icon(
                    Icons.drag_handle_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
