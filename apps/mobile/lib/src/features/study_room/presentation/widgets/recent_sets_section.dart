import 'package:flutter/material.dart';

import '../../infra/study_room_recent_room.dart';

/// 최근 접속한 셋을 가로 스크롤 카드로 표시.
/// 카드 상단: 스터디 그룹 목표 / 하단: 참석자.
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
                    ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 32 - 8 * 2) / 3;
            return SizedBox(
              height: 100,
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
    final goal = room.goalText.trim().isEmpty ? '목표를 설정해 보세요' : room.goalText;

    return SizedBox(
      width: width,
      child: Material(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: joining ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal,
                  style: tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 12,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        room.participantsLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
