import 'package:flutter/material.dart';

import '../data/motivation_repository.dart';
import '../domain/motivation_models.dart';

/// 미션: 주간 챌린지 규칙 안내 + 팀별 진행 요약
class SocialMissionTab extends StatelessWidget {
  final MotivationRepository repo;

  const SocialMissionTab({
    super.key,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<List<SquadRow>>(
      future: repo.mySquads(),
      builder: (context, snap) {
        final squads = snap.data ?? const <SquadRow>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('이번 주 미션이란?', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(
                      '• 팀마다 정해진 「목표 시간」을 멤버들의 집중 공부 시간으로 채워요.\n'
                      '• 기간은 보통 월요일~일요일(서버 주차) 기준이에요.\n'
                      '• 목표는 「팀」 탭에서 만들 때 고르거나, 팀장이 정한 값을 따라요.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.45,
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('내 팀 진행', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (squads.isEmpty)
              Text(
                '참여 중인 챌린지 팀이 없어요. 「팀」 탭에서 팀을 만들거나 참가해 주세요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              )
            else
              ...squads.map((s) => _MissionSummaryTile(repo: repo, squad: s)),
          ],
        );
      },
    );
  }
}

class _MissionSummaryTile extends StatelessWidget {
  final MotivationRepository repo;
  final SquadRow squad;

  const _MissionSummaryTile({required this.repo, required this.squad});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: repo.squadWeekProgress(squad.id),
      builder: (context, progSnap) {
        final ratio = progSnap.data == null
            ? 0.0
            : ((progSnap.data!['ratio'] ?? 0) as num).toDouble();
        final sec = progSnap.data == null
            ? 0
            : ((progSnap.data!['team_focused_seconds'] ?? 0) as num).toInt();
        final h = sec ~/ 3600;
        final m = (sec % 3600) ~/ 60;
        final spent = h > 0 ? '$h시간 $m분' : '$m분';
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(squad.name, style: Theme.of(context).textTheme.titleMedium),
                Text('멤버 합산 $spent', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: ratio.clamp(0.0, 1.0)),
              ],
            ),
          ),
        );
      },
    );
  }
}
