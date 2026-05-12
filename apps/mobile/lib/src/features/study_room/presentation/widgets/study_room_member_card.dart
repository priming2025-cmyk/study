import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/study_room_models.dart';

part 'study_room_member_card_part.dart';

class StudyRoomMemberCard extends StatelessWidget {
  final StudyRoomMember member;
  final bool isSelf;
  /// 좁은 오른쪽 열: 목표·과목·응원 칩 생략.
  final bool compact;
  final String? floatingReaction;
  final void Function(String emoji)? onQuickReact;

  const StudyRoomMemberCard({
    super.key,
    required this.member,
    required this.isSelf,
    this.compact = false,
    this.floatingReaction,
    this.onQuickReact,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final snapshotUrl = member.snapshotUrl;

    final borderColor = member.status == 'focus'
        ? Colors.redAccent.withAlpha(200)
        : (member.status == 'rest' ? Colors.blueAccent.withAlpha(200) : Colors.transparent);
    final borderWidth = member.status == 'focus' || member.status == 'rest' ? 3.0 : 0.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (snapshotUrl != null)
            Image.network(
              snapshotUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _Placeholder(cs: cs),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _Placeholder(cs: cs),
            )
          else
            _Placeholder(cs: cs),

          if (member.joinAt != null && !compact)
            Positioned(
              top: 6,
              left: 6,
              child: _JoinElapsedBadge(joinAt: member.joinAt!),
            ),

          if (floatingReaction != null && floatingReaction!.isNotEmpty)
            _FloatingReaction(
              key: ValueKey(floatingReaction),
              emoji: floatingReaction!,
            ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withAlpha(180)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onQuickReact != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: compact ? 2 : 4),
                      child: Row(
                        children: [
                          _ReactChip(label: '🔥', onTap: () => onQuickReact!('🔥')),
                          _ReactChip(label: '👍', onTap: () => onQuickReact!('👍')),
                          _ReactChip(label: '💪', onTap: () => onQuickReact!('💪')),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isSelf ? '나' : member.displayName ?? member.userId.substring(0, 8),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 11 : 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (member.status == 'focus')
                        const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 14)
                      else if (member.status == 'rest')
                        const Icon(Icons.coffee, color: Colors.blueAccent, size: 14),
                      if (isSelf)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary.withAlpha(200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('나', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                    ],
                  ),
                  if (member.publicLevel != null || (member.publicTitleKo != null && member.publicTitleKo!.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [
                          if (member.publicLevel != null) 'Lv.${member.publicLevel}',
                          if (member.publicTitleKo != null && member.publicTitleKo!.isNotEmpty)
                            member.publicTitleKo!,
                        ].join(' · '),
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (!compact && member.goalText != null && member.goalText!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '목표: ${member.goalText}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  if (!compact && member.subjectName != null && member.subjectName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        member.subjectName!,
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (member.snapshotAt != null)
            Positioned(
              top: 6,
              right: 6,
              child: _SnapshotAge(at: member.snapshotAt!),
            ),
        ],
      ),
    );
  }
}
