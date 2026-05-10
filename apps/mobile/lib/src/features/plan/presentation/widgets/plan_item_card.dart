import 'package:flutter/material.dart';

import '../../data/plan_models.dart';

class PlanItemCard extends StatelessWidget {
  final PlanItem item;
  final VoidCallback onDelete;
  final ValueChanged<bool> onDoneChanged;
  final ValueChanged<int> onActualMinutesChanged;

  const PlanItemCard({
    super.key,
    required this.item,
    required this.onDelete,
    required this.onDoneChanged,
    required this.onActualMinutesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final targetMin = (item.targetSeconds / 60).round();
    final actualMin = (item.actualSeconds / 60).round();
    final rate = item.completionRate;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.subject,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: '삭제',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: rate),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${(rate * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('목표 $targetMin분',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 12),
                Text('실제 $actualMin분',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
                const Spacer(),
                Checkbox(
                  value: item.isDone,
                  onChanged: (v) => onDoneChanged(v ?? false),
                ),
                const Text('완료'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <int>{0, 25, 50, 60, targetMin}.map((m) {
                final selected = actualMin == m;
                return ChoiceChip(
                  label: Text('$m' 'm'),
                  selected: selected,
                  onSelected: (_) => onActualMinutesChanged(m),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

