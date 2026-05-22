import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'friend_status_section.dart';
import 'study_group_browser_sheet.dart';

/// 인스타그램 DM 목록 느낌의 셋터디 친구 피드.
class SettudySocialView extends ConsumerWidget {
  final VoidCallback onCreateRoom;
  final VoidCallback? onQuickJoinRecent;
  final String? recentRoomId;
  final bool joining;

  const SettudySocialView({
    super.key,
    required this.onCreateRoom,
    this.onQuickJoinRecent,
    this.recentRoomId,
    this.joining = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final friends = ref.watch(friendPresenceProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Text('셋터디',
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  tooltip: '그룹 찾기',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => _openGroupBrowser(context),
                ),
              ],
            ),
          ),
        ),
        if (recentRoomId != null && onQuickJoinRecent != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _QuickJoinChip(
                roomId: recentRoomId!,
                onTap: joining ? null : onQuickJoinRecent,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('친구',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ),
        friends.when(
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyFriends(onCreateRoom: onCreateRoom, cs: cs, tt: tt),
          ),
          data: (list) {
            if (list.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyFriends(onCreateRoom: onCreateRoom, cs: cs, tt: tt),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final f = list[i];
                  return _FriendDmTile(friend: f);
                },
                childCount: list.length,
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ],
    );
  }

  void _openGroupBrowser(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudyGroupBrowserSheet(
        onApply: (group) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('「${group.name}」 가입 신청 완료')),
          );
        },
      ),
    );
  }
}

class _FriendDmTile extends StatelessWidget {
  final FriendPresence friend;

  const _FriendDmTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isStudying = friend.status == FriendStudyStatus.studying;
    final isOnline = friend.status == FriendStudyStatus.online;

    return Material(
      color: cs.surface,
      child: InkWell(
        onTap: () => _openDmSheet(context, friend),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: cs.secondaryContainer,
                    child: Text(
                      friend.displayName.isNotEmpty
                          ? friend.displayName[0].toUpperCase()
                          : '?',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isStudying
                            ? Colors.red.shade400
                            : isOnline
                                ? Colors.green.shade400
                                : cs.outline,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusLine(friend),
                      style: tt.bodySmall?.copyWith(
                        color: isStudying
                            ? Colors.red.shade400
                            : cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isStudying)
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${friend.displayName}에게 응원 보냈어요 👊')),
                    );
                  },
                  child: const Text('응원'),
                )
              else if (isOnline)
                FilledButton.tonal(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${friend.displayName}에게 초대를 보냈어요')),
                    );
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(56, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('초대'),
                )
              else
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLine(FriendPresence f) {
    return switch (f.status) {
      FriendStudyStatus.studying =>
        f.studyingSubject != null ? '${f.studyingSubject} 집중 중' : '집중 중',
      FriendStudyStatus.online => '접속 중 · 오늘 계획 진행 중',
      FriendStudyStatus.offline =>
        f.lastSeenAgo != null ? '${f.lastSeenAgo} 접속' : '오프라인',
    };
  }

  void _openDmSheet(BuildContext context, FriendPresence friend) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DmSheet(friend: friend),
    );
  }
}

class _DmSheet extends StatefulWidget {
  final FriendPresence friend;

  const _DmSheet({required this.friend});

  @override
  State<_DmSheet> createState() => _DmSheetState();
}

class _DmSheetState extends State<_DmSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.55,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Text(widget.friend.displayName[0].toUpperCase()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.friend.displayName,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Center(
                child: Text(
                  '메시지를 보내보세요',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: '메시지...',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      if (_ctrl.text.trim().isEmpty) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${widget.friend.displayName}에게 전송')),
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickJoinChip extends StatelessWidget {
  final String roomId;
  final VoidCallback? onTap;

  const _QuickJoinChip({required this.roomId, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(Icons.history_rounded, size: 18, color: cs.primary),
      label: Text('최근 셋 ${roomId.length > 6 ? '${roomId.substring(0, 6)}…' : roomId}'),
      onPressed: onTap,
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  final VoidCallback onCreateRoom;
  final ColorScheme cs;
  final TextTheme tt;

  const _EmptyFriends({
    required this.onCreateRoom,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('아직 친구가 없어요',
              style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(
            '오른쪽 아래 + 로 셋을 만들거나\n그룹 찾기에서 함께 공부할 팀을 찾아보세요',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
