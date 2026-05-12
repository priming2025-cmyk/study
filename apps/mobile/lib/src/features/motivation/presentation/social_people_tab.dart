import 'package:flutter/material.dart';

import '../data/motivation_repository.dart';
import '../domain/motivation_models.dart';

/// 사람: 친구 요청·목록 (랭킹은 「경쟁」 탭)
class SocialPeopleTab extends StatelessWidget {
  final MotivationRepository repo;
  final TextEditingController peerIdCtrl;
  final VoidCallback onChanged;

  const SocialPeopleTab({
    super.key,
    required this.repo,
    required this.peerIdCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: Future.wait([
        repo.listFriends(),
        repo.pendingFriendRequestsIncoming(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final friends = snap.data![0] as List<FriendRow>;
        final incoming = snap.data![1] as List<Map<String, dynamic>>;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('친구 맺기', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              '상대의 프로필 UUID를 입력해 요청을 보내요. 수락되면 챌린지·랭킹에 함께 표시돼요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: peerIdCtrl,
                    decoration: const InputDecoration(
                      labelText: '친구 UUID',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final id = peerIdCtrl.text.trim();
                    if (id.isEmpty) return;
                    try {
                      await repo.sendFriendRequest(toUserId: id);
                      peerIdCtrl.clear();
                      onChanged();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('친구 요청을 보냈어요.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('요청 실패: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('보내기'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (incoming.isNotEmpty) ...[
              Text('받은 요청', style: Theme.of(context).textTheme.titleSmall),
              ...incoming.map((r) {
                return ListTile(
                  title: Text('from ${r['from_user_id']}'),
                  trailing: FilledButton(
                    onPressed: () async {
                      await repo.acceptFriendRequest(r['id'] as String);
                      onChanged();
                    },
                    child: const Text('수락'),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            Text('내 친구', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (friends.isEmpty)
              Text(
                '아직 친구가 없어요. 위에서 요청을 보내 보세요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              ...friends.map(
                (f) => ListTile(
                  leading: CircleAvatar(child: Text('Lv.${f.level}')),
                  title: Text(f.displayName),
                  subtitle: Text(f.peerId, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
          ],
        );
      },
    );
  }
}
