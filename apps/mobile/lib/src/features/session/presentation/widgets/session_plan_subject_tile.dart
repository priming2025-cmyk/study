import 'package:flutter/material.dart';

import '../../../plan/data/plan_models.dart';
import '../../../plan/presentation/widgets/subject_preset_picker.dart';

/// 집중 세션에서 오늘 계획의 한 과목을 선택할 때 쓰는 타일(탭=선택, 연필/휴지통=편집·삭제).
class SessionPlanSubjectTile extends StatelessWidget {
  final PlanItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SessionPlanSubjectTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = subjectColor(item.subject);
    final targetMin = (item.targetSeconds / 60).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? color.withValues(alpha: 0.12) : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.55) : cs.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 22,
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
                              const SizedBox(height: 2),
                              Text(
                                '목표 $targetMin분${item.isDone ? ' · 완료' : ''}',
                                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle, color: color, size: 22)
                        else
                          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: '과목·목표 시간·알림 수정',
                icon: Icon(Icons.edit_outlined, color: cs.primary, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: '계획에서 삭제',
                icon: Icon(Icons.delete_outline, color: cs.onSurfaceVariant, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
