import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/motivation_repository.dart';
import '../domain/motivation_models.dart';

/// 경쟁: 친구 주간 랭킹 (상세 그래프는 기록 탭)
class SocialCompeteTab extends StatelessWidget {
  final MotivationRepository repo;

  const SocialCompeteTab({
    super.key,
    required this.repo,
  });

  static String _fmt(int sec) {
    if (sec <= 0) return '0분';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분';
    return '$m분';
  }

  static int _lvl(List<FriendRow> friends, String peerId) {
    for (final f in friends) {
      if (f.peerId == peerId) return f.level;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<List<Object>>(
      future: Future.wait([repo.listFriends(), repo.friendWeekRankings()]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final friends = snap.data![0] as List<FriendRow>;
        final ranks = snap.data![1] as List<FriendRankRow>;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: cs.surfaceContainerHighest.withAlpha(160),
              child: ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: const Text('집중 그래프·합계는 기록 탭'),
                subtitle: const Text('일별 막대와 나의 블럭·레벨도 함께 확인해요.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/stats'),
              ),
            ),
            const SizedBox(height: 16),
            Text('이번 주 친구 랭킹', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              '월~일 기준 집중 시간 합산입니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (ranks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '친구를 맺으면 순위가 표시돼요.\n「사람」 탭에서 요청해 보세요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...ranks.map(
                (r) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${r.rank}')),
                    title: Text(r.displayName),
                    subtitle: Text('Lv.${_lvl(friends, r.peerId)} · ${_fmt(r.focusedSeconds)}'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
