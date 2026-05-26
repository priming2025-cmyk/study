import 'package:flutter/material.dart';

import '../../infra/study_room_recent_room.dart';

/// 최근 접속한 셋을 가로 스크롤 카드로 표시하는 섹션.
/// 3개까지 화면에 딱 맞게 보이고, 그 이상은 좌우 스와이프.
class RecentSetsSection extends StatelessWidget {
  final List<RecentStudyRoom> rooms;
  final bool joining;
  final void Function(RecentStudyRoom room) onJoin;

  const RecentSetsSection({
    super.key,
    required this.rooms,
    required this.joining,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) return const SizedBox.shrink();

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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // 화면에 딱 3개가 보이도록 카드 너비 계산
            final cardWidth = (constraints.maxWidth - 32 - 8 * 2) / 3;
            return SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: rooms.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _RecentSetCard(
                  room: rooms[i],
                  width: cardWidth,
                  joining: joining,
                  onTap: () => onJoin(rooms[i]),
                ),
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

  const _RecentSetCard({
    required this.room,
    required this.width,
    required this.joining,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      width: width,
      child: Material(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: joining ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.groups_2_rounded,
                      size: 14,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        room.lastAccessedLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    room.roomName,
                    style: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (room.goalText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    room.goalText,
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
