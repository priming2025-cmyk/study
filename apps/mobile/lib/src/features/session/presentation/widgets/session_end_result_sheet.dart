import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/session_reward_result.dart';

class SessionEndResultSheet extends StatelessWidget {
  final SessionRewardResult reward;
  final int averageScore;
  final int focusedSeconds;

  const SessionEndResultSheet({
    super.key,
    required this.reward,
    required this.averageScore,
    required this.focusedSeconds,
  });

  static String _fmtMin(int sec) {
    final m = (sec / 60).floor();
    return '$m분';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: cs.onSurface.withAlpha(35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '공부 완료',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '집중 ${_fmtMin(focusedSeconds)} · 평균 점수 $averageScore점',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _row(context, label: '집중 공부', value: '+${reward.blocksFromFocus} 블럭'),
                    _row(context, label: '계획 달성 보너스', value: reward.planBonus > 0 ? '+${reward.planBonus} 블럭' : '0'),
                    _row(context, label: '연속 달성 보너스', value: reward.streakBonus > 0 ? '+${reward.streakBonus} 블럭' : '0'),
                    const Divider(height: 18),
                    _row(
                      context,
                      label: '총 블럭',
                      value: '+${reward.totalBlocks} 블럭',
                      strong: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/coins');
                    },
                    child: const Text('내역 보기'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/session/quick');
                    },
                    child: const Text('다음 공부'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/plan');
              },
              child: const Text('계획짜기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required String value,
    bool strong = false,
  }) {
    final style = strong
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

