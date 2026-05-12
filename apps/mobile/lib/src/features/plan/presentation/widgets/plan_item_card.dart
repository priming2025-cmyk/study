import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/plan_models.dart';
import 'subject_preset_picker.dart';

class PlanItemCard extends StatelessWidget {
  final PlanItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onDoneChanged;
  final ValueChanged<int> onActualMinutesChanged;

  const PlanItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onDoneChanged,
    required this.onActualMinutesChanged,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: isDone
            ? cs.surfaceContainerLow
            : cs.surfaceContainerLowest,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDone
                    ? cs.outlineVariant
                    : color.withValues(alpha: 0.35),
                width: isDone ? 1 : 1.5,
              ),
            ),
            child: Column(
              children: [
                // 상단: 색상 바 + 과목명 + 삭제
                Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDone ? 0.06 : 0.12),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isDone ? color.withValues(alpha: 0.4) : color,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.subject,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDone ? cs.onSurfaceVariant : cs.onSurface,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            decorationColor: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      // 완료 체크(동그라미/네모 모양은 플랫폼 기본 체크박스)
                      Tooltip(
                        message: '계획 완료 표시',
                        child: Transform.scale(
                          scale: 0.9,
                          child: Checkbox(
                            value: isDone,
                            activeColor: color,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            onChanged: (v) => onDoneChanged(v ?? false),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '과목·목표 시간 수정',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        color: cs.primary,
                        visualDensity: VisualDensity.compact,
                        onPressed: onEdit,
                      ),
                      IconButton(
                        tooltip: '삭제',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: cs.onSurfaceVariant,
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ),

                if (item.scheduledStartAt != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Row(
                      children: [
                        Icon(
                          item.reminderEnabled
                              ? Icons.notifications_active_outlined
                              : Icons.schedule,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '시작 ${DateFormat('M/d HH:mm', 'ko').format(item.scheduledStartAt!.toLocal())}',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.reminderEnabled) ...[
                          const SizedBox(width: 8),
                          Text(
                            '알림',
                            style: tt.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // 하단: 진행률 + 시간 칩
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 프로그레스 바
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: rate,
                                color: isDone
                                    ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                                    : color,
                                backgroundColor: color.withValues(alpha: 0.12),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(rate * 100).round()}%',
                            style: tt.labelSmall?.copyWith(
                              color: isDone ? cs.onSurfaceVariant : color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 실제시간 칩 + 목표 표시
                      Row(
                        children: [
                          Text(
                            '목표 $targetMin분',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (actualMin > 0)
                            Text(
                              '실제 $actualMin분',
                              style: tt.bodySmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const Spacer(),
                          // 실제시간 빠른 칩
                          ...<int>{0, targetMin ~/ 2, targetMin}.map((m) {
                            final sel = actualMin == m;
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: ChoiceChip(
                                label: Text('$m분',
                                    style: const TextStyle(fontSize: 11)),
                                selected: sel,
                                selectedColor: color.withValues(alpha: 0.18),
                                checkmarkColor: color,
                                visualDensity: VisualDensity.compact,
                                labelStyle: TextStyle(
                                  color: sel ? color : cs.onSurfaceVariant,
                                  fontWeight:
                                      sel ? FontWeight.w700 : FontWeight.w500,
                                ),
                                side: BorderSide(
                                  color: sel
                                      ? color
                                      : cs.outlineVariant,
                                ),
                                onSelected: (_) => onActualMinutesChanged(m),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
