import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../motivation/domain/motivation_models.dart';
import 'friend_find_sheet.dart';
import 'friend_status_section.dart';
import 'recent_sets_section.dart';
import 'study_group_browser_sheet.dart';
import '../../infra/study_room_recent_room.dart';

/// 셋터디 탭 메인 화면 (로비).
/// 상단: 최근 셋(목표·참석자) / 하단: 인스타그램 DM 형식 메시지 목록.
class SettudySocialView extends ConsumerWidget {
  final VoidCallback onCreateRoom;
  final List<RecentStudyRoom> recentRooms;
  final void Function(RecentStudyRoom room) onJoinRoom;
  final bool joining;

  const SettudySocialView({
    super.key,
    required this.onCreateRoom,
    required this.recentRooms,
    required this.onJoinRoom,
    this.joining = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final friends = ref.watch(settudyDmFriendsProvider);

    return CustomScrollView(
      slivers: [
        if (recentRooms.isNotEmpty)
          SliverToBoxAdapter(
            child: RecentSetsSection(
              rooms: recentRooms,
              joining: joining,
              onJoin: onJoinRoom,
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
                  onPressed: () => FriendFindSheet.show(context),
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
        friends.when(
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
                  final f = list[i];
                  final isLast = i == list.length - 1;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FriendDmTile(friend: f),
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

/// 인스타그램 DM 목록 한 줄.
class _FriendDmTile extends StatelessWidget {
  final FriendRow friend;

  const _FriendDmTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surface,
      child: InkWell(
        onTap: () => _openDmSheet(context, friend),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '메시지를내보세요',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Lv.${friend.level}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 18,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDmSheet(BuildContext context, FriendRow friend) {
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
  final FriendRow friend;

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
        height: MediaQuery.of(context).size.height * 0.65,
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.secondaryContainer,
                    child: Text(
                      widget.friend.displayName[0].toUpperCase(),
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.friend.displayName,
                          style: tt.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Lv.${widget.friend.level}',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 40,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '메시지를내보세요',
                      style: tt.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
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
                        SnackBar(
                          content: Text(
                              '${widget.friend.displayName}에게 전송됐어요'),
                        ),
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
            '친구찾기로 이름·이메일을 검색하거나\n+ 버튼으로 셋을 만들어 보세요',
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
