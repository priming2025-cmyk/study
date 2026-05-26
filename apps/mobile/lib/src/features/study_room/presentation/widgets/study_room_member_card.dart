import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/study_room_models.dart';
import 'study_room_member_viewer_sheet.dart';

part 'study_room_member_card_part.dart';

class StudyRoomMemberCard extends StatelessWidget {
  final StudyRoomMember member;
  final bool isSelf;
  /// 좁은 오른쪽 열: 목표·과목·응원 칩 생략.
  final bool compact;
  final String? floatingReaction;
  final void Function(String emoji)? onQuickReact;
  /// DM 채팅 열기
  final VoidCallback? onChat;

  const StudyRoomMemberCard({
    super.key,
    required this.member,
    required this.isSelf,
    this.compact = false,
    this.floatingReaction,
    this.onQuickReact,
    this.onChat,
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

          // 피어 카드에만 표시: 우측 아이콘 열 (말풍선 / 하트 / 모니터)
          if (!isSelf)
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IconBtn(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: '메시지',
                    onTap: () {
                      if (onChat != null) {
                        onChat!();
                      } else {
                        _showChatSnack(context);
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  _IconBtn(
                    icon: Icons.favorite_outline_rounded,
                    tooltip: '응원',
                    onTap: () {
                      if (onQuickReact != null) {
                        onQuickReact!('❤️');
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  _IconBtn(
                    icon: Icons.monitor_outlined,
                    tooltip: '영상/사진 보기',
                    onTap: () => StudyRoomMemberViewerSheet.show(
                      context,
                      member: member,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showChatSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${member.displayName ?? '친구'}에게 메시지를 보냈어요',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(100),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
