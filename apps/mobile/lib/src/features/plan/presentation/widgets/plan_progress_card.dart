import 'package:flutter/material.dart';

class PlanProgressCard extends StatelessWidget {
  final double completionRate;
  final int totalActualSeconds;
  final int totalTargetSeconds;

  const PlanProgressCard({
    super.key,
    required this.completionRate,
    required this.totalActualSeconds,
    required this.totalTargetSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final hasPlan = totalTargetSeconds > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('달성률', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: completionRate),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${(completionRate * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hasPlan
                  ? '${_fmt(totalActualSeconds)} / ${_fmt(totalTargetSeconds)}'
                  : '계획을 만들면 자동으로 달성률이 계산돼요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final h = m ~/ 60;
    final mm = m % 60;
    if (h > 0) return '${h}h ${mm}m';
    return '${m}m';
  }
}

