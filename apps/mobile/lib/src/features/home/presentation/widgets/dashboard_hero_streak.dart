import 'package:flutter/material.dart';

import '../../../motivation/domain/motivation_models.dart';
import '../../../stats/data/daily_focus_stat.dart';

/// 홈 상단 히어로 카드 (레벨·칭호). 코인·주간 미션은 기록 탭에서 확인.
class DashboardHeroCard extends StatelessWidget {
  final String? email;
  final ProfileRpgSummary? rpg;
  final VoidCallback? onChangeTitle;

  const DashboardHeroCard({
    super.key,
    required this.email,
    this.rpg,
    this.onChangeTitle,
  });

  @override
  Widget build(BuildContext context) {
    final summary = rpg;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘도 꾸준히',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '계획 → 집중 → 기록 → 분석',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (summary != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lv.${summary.level} · XP ${summary.xpTotal}'
                      '${summary.equippedTitleKo != null ? ' · ${summary.equippedTitleKo}' : ''}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  if (onChangeTitle != null)
                    TextButton(
                      onPressed: onChangeTitle,
                      child: const Text('칭호'),
                    ),
                ],
              ),
            ],
            if (email != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      email!,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 최근 7일 집중 잔디 + 스트릭 요약.
class DashboardStreakGrassCard extends StatelessWidget {
  final List<DailyFocusStat> last7Days;
  final int streak;

  const DashboardStreakGrassCard({
    super.key,
    required this.last7Days,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('연속·잔디', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '스트릭 $streak일 · 최근 7일 집중 여부',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: last7Days.map((d) {
                final on = d.focusedSeconds > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: on
                              ? Theme.of(context).colorScheme.primary.withAlpha(180)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
