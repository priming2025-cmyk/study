import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../social/data/friend_dm_providers.dart';
import '../../../social/domain/friend_dm_models.dart';
import '../../../social/presentation/friend_dm_listener.dart';
import '../../infra/study_room_recent_room.dart';
import 'friend_find_sheet.dart';
import 'friend_incoming_requests_section.dart';
import 'recent_sets_section.dart';

/// 셋터디 탭 메인 화면 (로비).
/// 상단: 최근 셋 / 받은 친구 요청 / 인스타 DM형 메시지 목록.
class SettudySocialView extends ConsumerStatefulWidget {
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinByCode;
  final List<RecentStudyRoom> recentRooms;
  final void Function(RecentStudyRoom room) onJoinRoom;
  final void Function(RecentStudyRoom room) onInviteRoom;
  final bool joining;

  const SettudySocialView({
    super.key,
    required this.onCreateRoom,
    required this.onJoinByCode,
    required this.recentRooms,
    required this.onJoinRoom,
    required this.onInviteRoom,
    this.joining = false,
  });

  @override
  ConsumerState<SettudySocialView> createState() => _SettudySocialViewState();
}

class _SettudySocialViewState extends ConsumerState<SettudySocialView> {
  int _refreshKey = 0;

  void _refreshFriends() {
    setState(() => _refreshKey++);
    ref.invalidate(friendDmThreadsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final threads = ref.watch(friendDmThreadsProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: RecentSetsSection(
            rooms: widget.recentRooms,
            joining: widget.joining,
            onJoin: widget.onJoinRoom,
            onInvite: widget.onInviteRoom,
            onCreateRoom: widget.onCreateRoom,
            onJoinByCode: widget.onJoinByCode,
          ),
        ),
        SliverToBoxAdapter(
          child: FriendIncomingRequestsSection(
            key: ValueKey('incoming_$_refreshKey'),
            onChanged: _refreshFriends,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Text(
                  '메시지',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => FriendFindSheet.show(context).then((_) {
                    _refreshFriends();
                  }),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('친구찾기'),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16),
        ),
        threads.when(
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyFriends(cs: cs, tt: tt),
          ),
          data: (list) {
            if (list.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyFriends(cs: cs, tt: tt),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final t = list[i];
                  final isLast = i == list.length - 1;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FriendDmTile(
                        thread: t,
                        onTap: () => openFriendDmChat(
                          context,
                          ref,
                          peerId: t.peerId,
                          peerDisplayName: t.peerDisplayName,
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 72,
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                        ),
                    ],
                  );
                },
                childCount: list.length,
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

class _FriendDmTile extends StatelessWidget {
  final FriendDmThread thread;
  final VoidCallback onTap;

  const _FriendDmTile({
    required this.thread,
    required this.onTap,
  });

  String _preview() {
    final c = thread.lastContent?.trim();
    if (c != null && c.isNotEmpty) return c;
    return '메시지를 보내보세요';
  }

  String _timeLabel() {
    final at = thread.lastAt;
    if (at == null) return '';
    final local = at.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${local.month}/${local.day}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final unread = thread.unreadCount > 0;

    return Material(
      color: unread ? cs.primaryContainer.withAlpha(40) : cs.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: cs.secondaryContainer,
                    child: Text(
                      thread.peerDisplayName.isNotEmpty
                          ? thread.peerDisplayName[0].toUpperCase()
                          : '?',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                  if (unread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 2),
                        ),
                        child: Text(
                          thread.unreadCount > 9
                              ? '9+'
                              : '${thread.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.peerDisplayName,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _preview(),
                      style: tt.bodyMedium?.copyWith(
                        color: unread
                            ? cs.onSurface
                            : cs.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight:
                            unread ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_timeLabel().isNotEmpty)
                Text(
                  _timeLabel(),
                  style: TextStyle(
                    fontSize: 12,
                    color: unread ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: unread ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;

  const _EmptyFriends({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_outlined,
            size: 52,
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '아직 대화할 친구가 없어요',
            style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            '친구찾기로 이름을 검색하거나\n+ 버튼으로 셋을 만들어 보세요',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: () => FriendFindSheet.show(context),
            child: const Text('친구찾기'),
          ),
        ],
      ),
    );
  }
}
