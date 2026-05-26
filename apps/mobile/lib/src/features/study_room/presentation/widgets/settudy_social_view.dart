import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'contacts_import_sheet.dart';
import 'friend_status_section.dart';
import 'recent_sets_section.dart';
import 'study_group_browser_sheet.dart';
import '../../infra/study_room_recent_room.dart';

/// 셋터디 탭 메인 화면 (로비).
/// 상단: 최근 셋 카드 / 하단: 인스타그램 DM 형식 친구 목록.
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
    final friends = ref.watch(friendPresenceProvider);

    return CustomScrollView(
      slivers: [
        // ── 헤더 ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Text(
                  '셋터디',
                  style: tt.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '그룹 검색',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => _openGroupBrowser(context),
                ),
              ],
            ),
          ),
        ),

        // ── 최근 셋 카드 섹션 ──────────────────────────────
        if (recentRooms.isNotEmpty)
          SliverToBoxAdapter(
            child: RecentSetsSection(
              rooms: recentRooms,
              joining: joining,
              onJoin: onJoinRoom,
            ),
          ),

        // ── 메시지 섹션 헤더 ──────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  '메시지',
                  style: tt.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => ContactsImportSheet.show(context),
                  icon: const Icon(Icons.contacts_rounded, size: 16),
                  label: const Text('연락처'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Divider(height: 1, indent: 16, endIndent: 16),
        ),

        // ── 친구 DM 목록 ──────────────────────────────────
        friends.when(
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyFriends(
              onCreateRoom: onCreateRoom,
              cs: cs,
              tt: tt,
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyFriends(
                  onCreateRoom: onCreateRoom,
                  cs: cs,
                  tt: tt,
                ),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _FriendDmTile(friend: list[i]),
                childCount: list.length,
              ),
            );
          },
        ),

        // FAB 여백
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

// ─────────────────────────────────────────────────────────────────────────────
// 친구 DM 타일 — 인스타그램 DM 형식
// ─────────────────────────────────────────────────────────────────────────────

class _FriendDmTile extends StatelessWidget {
  final FriendPresence friend;

  const _FriendDmTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isStudying = friend.status == FriendStudyStatus.studying;
    final isOnline = friend.status == FriendStudyStatus.online;

    final statusColor = isStudying
        ? Colors.red.shade400
        : isOnline
            ? Colors.green.shade400
            : cs.outline;

    return Material(
      color: cs.surface,
      child: InkWell(
        onTap: () => _openDmSheet(context, friend),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              // 아바타 + 활동 점
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
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // 이름 + 최근 메세지
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _recentMessage(friend),
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

              // 활동 시간
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _activityTime(friend),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _recentMessage(FriendPresence f) {
    return switch (f.status) {
      FriendStudyStatus.studying =>
        f.studyingSubject != null ? '📚 ${f.studyingSubject} 집중 중' : '📚 집중 공부 중',
      FriendStudyStatus.online => '접속 중',
      FriendStudyStatus.offline =>
        f.lastSeenAgo != null ? '${f.lastSeenAgo} 접속' : '오프라인',
    };
  }

  String _activityTime(FriendPresence f) {
    return switch (f.status) {
      FriendStudyStatus.studying => '공부 중',
      FriendStudyStatus.online => '온라인',
      FriendStudyStatus.offline => f.lastSeenAgo ?? '',
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

// ─────────────────────────────────────────────────────────────────────────────
// DM 채팅 시트
// ─────────────────────────────────────────────────────────────────────────────

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
            // DM 헤더
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
                          _statusLabel(widget.friend.status),
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (widget.friend.status == FriendStudyStatus.online)
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${widget.friend.displayName}에게 초대를 보냈어요'),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(56, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('초대'),
                    )
                  else if (widget.friend.status == FriendStudyStatus.studying)
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${widget.friend.displayName}에게 응원 보냈어요 👊'),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(56, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('응원 👊'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // 메시지 영역
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
                      '메시지를 보내보세요',
                      style: tt.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            // 입력창
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

  String _statusLabel(FriendStudyStatus status) => switch (status) {
        FriendStudyStatus.studying => '집중 공부 중',
        FriendStudyStatus.online => '온라인',
        FriendStudyStatus.offline => '오프라인',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// 친구 없을 때 빈 화면
// ─────────────────────────────────────────────────────────────────────────────

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
          Icon(
            Icons.people_outline_rounded,
            size: 52,
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '아직 친구가 없어요',
            style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            '연락처에서 셋터디 친구를 찾거나\n+ 버튼으로 셋을 만들어 보세요',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: () => ContactsImportSheet.show(context),
            icon: const Icon(Icons.contacts_rounded),
            label: const Text('연락처에서 친구 찾기'),
          ),
        ],
      ),
    );
  }
}
