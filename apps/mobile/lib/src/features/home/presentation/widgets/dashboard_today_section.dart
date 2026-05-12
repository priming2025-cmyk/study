import 'package:flutter/material.dart';

/// 오늘 집중·계획 달성 요약 카드.
class DashboardTodayMetricsCard extends StatelessWidget {
  final int focusedSeconds;
  final int planTargetSeconds;
  final int planActualSeconds;
  final double completionRate;
  final bool loading;

  const DashboardTodayMetricsCard({
    super.key,
    required this.focusedSeconds,
    required this.planTargetSeconds,
    required this.planActualSeconds,
    required this.completionRate,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final focusedText = _formatSeconds(focusedSeconds);
    final planText = planTargetSeconds <= 0
        ? '아직 계획이 없어요'
        : '${_formatSeconds(planActualSeconds)} / ${_formatSeconds(planTargetSeconds)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: '집중시간',
                    value: loading ? '불러오는 중…' : focusedText,
                    icon: Icons.timer_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    label: '계획 달성률',
                    value: loading ? '불러오는 중…' : '${(completionRate * 100).round()}%',
                    icon: Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              planText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: completionRate),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
