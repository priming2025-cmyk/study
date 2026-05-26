import 'package:flutter/material.dart';

import '../../../motivation/domain/motivation_models.dart';
import '../../../stats/data/daily_focus_stat.dart';

/// 홈 상단 히어로 카드 (레벨·칭호). 코인·주간 미션은 기록 탭에서 확인.
class DashboardHeroCard extends StatelessWidget {
  final String? email;
  final ProfileRpgSummary? rpg;

  const DashboardHeroCard({
    super.key,
    required this.email,
    this.rpg,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final summary = rpg;
    final dark = Color.lerp(cs.primary, Colors.black, 0.28)!;
    final mid = Color.lerp(cs.primary, const Color(0xFFD4607A), 0.4)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [dark, cs.primary, mid],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 왼쪽: 레벨 배지
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(28),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  summary != null ? '${summary.level}' : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 오른쪽: 계급 + XP
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary?.currentRankKo ?? '세투디 학생',
                    style: tt.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary == null
                        ? '공부를 시작하면 레벨이 올라요'
                        : summary.nextRankKo == null
                            ? 'XP ${summary.xpTotal} · 최고 계급 달성!'
                            : '다음: ${summary.nextRankKo}  ·  +${summary.xpToNextRank ?? 0} XP',
                    style: tt.bodySmall?.copyWith(
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                  if (summary != null) ...[
                    const SizedBox(height: 10),
                    _XpBar(
                      xpTotal: summary.xpTotal,
                      xpToNext: summary.xpToNextRank,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  final int xpTotal;
  final int? xpToNext;
  const _XpBar({required this.xpTotal, required this.xpToNext});

  @override
  Widget build(BuildContext context) {
    final progress = xpToNext == null || xpToNext! <= 0
        ? 1.0
        : (1.0 - xpToNext! / (xpToNext! + xpTotal).clamp(1, double.infinity)).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.white.withAlpha(40),
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        minHeight: 5,
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
