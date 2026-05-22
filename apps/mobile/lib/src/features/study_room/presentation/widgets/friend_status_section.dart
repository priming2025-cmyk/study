import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 친구 실시간 상태 열거형.
enum FriendStudyStatus {
  studying,   // 집중 중 (공부 세션 실행 중) → 초대 불가
  online,     // 온라인 (앱 접속 중) → 초대 가능
  offline,    // 오프라인
}

/// 친구 상태 데이터 모델.
class FriendPresence {
  final String userId;
  final String displayName;
  final FriendStudyStatus status;
  final String? lastSeenAgo;
  final String? studyingSubject;

  const FriendPresence({
    required this.userId,
    required this.displayName,
    required this.status,
    this.lastSeenAgo,
    this.studyingSubject,
  });
}

/// Supabase presence/friend 데이터를 가져오는 Provider.
/// 실제 구현은 Supabase Realtime presence 채널 또는 DB poll을 사용.
final friendPresenceProvider =
    FutureProvider.autoDispose<List<FriendPresence>>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return const [];
  try {
    // profiles 테이블에서 팔로잉 친구 목록 + 온라인 상태 조회
    final result = await Supabase.instance.client
        .from('friend_presences')
        .select('user_id, display_name, status, last_seen_at, studying_subject')
        .limit(20);

    return (result as List).map((row) {
      final statusStr = row['status'] as String? ?? 'offline';
      final status = switch (statusStr) {
        'studying' => FriendStudyStatus.studying,
        'online' => FriendStudyStatus.online,
        _ => FriendStudyStatus.offline,
      };
      return FriendPresence(
        userId: row['user_id'] as String,
        displayName: row['display_name'] as String? ?? '친구',
        status: status,
        studyingSubject: row['studying_subject'] as String?,
        lastSeenAgo: _formatLastSeen(row['last_seen_at'] as String?),
      );
    }).toList();
  } catch (_) {
    return const [];
  }
});

String? _formatLastSeen(String? isoStr) {
  if (isoStr == null) return null;
  try {
    final dt = DateTime.parse(isoStr).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  } catch (_) {
    return null;
  }
}

/// 친구 실시간 상태 섹션 위젯.
class FriendStatusSection extends ConsumerWidget {
  final void Function(FriendPresence friend) onInvite;
  final void Function(FriendPresence friend) onCheer;

  const FriendStatusSection({
    super.key,
    required this.onInvite,
    required this.onCheer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final asyncFriends = ref.watch(friendPresenceProvider);

    return asyncFriends.when(
      loading: () => _buildSkeleton(cs),
      error: (_, __) => const SizedBox.shrink(),
      data: (friends) {
        if (friends.isEmpty) return const SizedBox.shrink();

        final online = friends
            .where((f) => f.status != FriendStudyStatus.offline)
            .toList();

        if (online.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
              child: Row(
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('친구 현황',
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${online.length}명 접속',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: online.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _FriendCard(
                  friend: online[i],
                  onInvite: () {
                    HapticFeedback.lightImpact();
                    onInvite(online[i]);
                  },
                  onCheer: () {
                    HapticFeedback.selectionClick();
                    onCheer(online[i]);
                  },
                  cs: cs,
                  tt: tt,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildSkeleton(ColorScheme cs) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => Container(
          width: 80,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final FriendPresence friend;
  final VoidCallback onInvite;
  final VoidCallback onCheer;
  final ColorScheme cs;
  final TextTheme tt;

  const _FriendCard({
    required this.friend,
    required this.onInvite,
    required this.onCheer,
    required this.cs,
    required this.tt,
  });

  Color get _statusColor => switch (friend.status) {
        FriendStudyStatus.studying => Colors.red.shade400,
        FriendStudyStatus.online => Colors.green.shade400,
        FriendStudyStatus.offline => Colors.grey.shade400,
      };

  String get _statusLabel => switch (friend.status) {
        FriendStudyStatus.studying => '집중 중',
        FriendStudyStatus.online => '온라인',
        FriendStudyStatus.offline => '오프라인',
      };

  @override
  Widget build(BuildContext context) {
    final isStudying = friend.status == FriendStudyStatus.studying;
    final isOnline = friend.status == FriendStudyStatus.online;

    return Container(
      width: 90,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isStudying
            ? Colors.red.shade50.withValues(alpha: 0.3)
            : isOnline
                ? cs.primaryContainer.withValues(alpha: 0.4)
                : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isStudying
              ? Colors.red.shade200
              : isOnline
                  ? cs.primary.withValues(alpha: 0.3)
                  : cs.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 아바타 + 상태 점
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cs.secondaryContainer,
                child: Text(
                  friend.displayName.isNotEmpty
                      ? friend.displayName[0].toUpperCase()
                      : '?',
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ),
              Positioned(
                bottom: -1,
                right: -1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 이름
          Text(
            friend.displayName.length > 5
                ? '${friend.displayName.substring(0, 5)}…'
                : friend.displayName,
            style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          // 상태 텍스트
          Text(
            isStudying && friend.studyingSubject != null
                ? friend.studyingSubject!
                : _statusLabel,
            style: TextStyle(
              fontSize: 9,
              color: _statusColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          // 버튼
          SizedBox(
            height: 24,
            child: isStudying
                ? OutlinedButton(
                    onPressed: onCheer,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 22),
                      textStyle: const TextStyle(fontSize: 10),
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                    child: const Text('응원 👊'),
                  )
                : FilledButton.tonal(
                    onPressed: onInvite,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 22),
                      textStyle: const TextStyle(fontSize: 10),
                    ),
                    child: const Text('초대'),
                  ),
          ),
        ],
      ),
    );
  }
}
