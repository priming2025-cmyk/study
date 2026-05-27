import 'package:flutter/material.dart';

import '../../domain/study_room_default_name.dart';
import '../../infra/study_room_recent_room.dart';

/// 최근 셋 가로 카드(최대 3). 3개 미만이면 같은 크기 카드에 셋 만들기·입장.
class RecentSetsSection extends StatelessWidget {
  static const _maxCards = 3;

  final List<RecentStudyRoom> rooms;
  final bool joining;
  final void Function(RecentStudyRoom room) onJoin;
  final void Function(RecentStudyRoom room) onInvite;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinByCode;

  const RecentSetsSection({
    super.key,
    required this.rooms,
    required this.joining,
    required this.onJoin,
    required this.onInvite,
    required this.onCreateRoom,
    required this.onJoinByCode,
  });

  @override
  Widget build(BuildContext context) {
    final shown = rooms.take(_maxCards).toList();
    final showQuickActions = shown.length < _maxCards;
    final itemCount = shown.length + (showQuickActions ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '최근 셋',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 32 - 8 * 2) / 3;
            return SizedBox(
              height: 136,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: itemCount,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  if (i < shown.length) {
                    return _RecentSetCard(
                      room: shown[i],
                      width: cardWidth,
                      joining: joining,
                      onTap: () => onJoin(shown[i]),
                      onLongPress: () => onInvite(shown[i]),
                    );
                  }
                  return _QuickActionCard(
                    width: cardWidth,
                    joining: joining,
                    onCreateRoom: onCreateRoom,
                    onJoinByCode: onJoinByCode,
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RecentSetCard extends StatelessWidget {
  final RecentStudyRoom room;
  final double width;
  final bool joining;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _RecentSetCard({
    required this.room,
    required this.width,
    required this.joining,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = room.roomName.trim().isNotEmpty
        ? room.roomName.trim()
        : kDefaultStudyRoomName;
    final participantCount = room.participantNames
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .length;
    final participantsText = formatParticipantNamesTwoLines(room.participantNames);
    final badgeText = '$participantCount/${room.maxPeers}';

    return SizedBox(
      width: width,
      child: Material(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: joining ? null : onTap,
          onLongPress: joining ? null : onLongPress,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style:
                            tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: tt.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  participantsText,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  room.lastActivityLabel,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 최근 셋 카드와 동일 크기 — 셋 만들기 · 입장.
class _QuickActionCard extends StatelessWidget {
  final double width;
  final bool joining;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinByCode;

  const _QuickActionCard({
    required this.width,
    required this.joining,
    required this.onCreateRoom,
    required this.onJoinByCode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      width: width,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: joining ? null : onCreateRoom,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    '셋 만들기',
                    style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: joining ? null : onJoinByCode,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    '입장',
                    style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
