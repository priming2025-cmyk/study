import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/study_room_models.dart';
import 'study_room_peer_dm_chip.dart';

part 'study_room_member_card_part.dart';

class StudyRoomMemberCard extends StatelessWidget {
  final StudyRoomMember member;
  final bool isSelf;
  /// 좁은 오른쪽 열: 목표·과목·응원 칩 생략.
  final bool compact;
  final String? floatingReaction;
  final void Function(String emoji)? onQuickReact;
  final VoidCallback? onChat;
  final String? dmPreview;
  final bool dmHasUnread;

  const StudyRoomMemberCard({
    super.key,
    required this.member,
    required this.isSelf,
    this.compact = false,
    this.floatingReaction,
    this.onQuickReact,
    this.onChat,
    this.dmPreview,
    this.dmHasUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final snapshotUrl = (member.snapshotUrl != null &&
            member.snapshotUrl!.isNotEmpty)
        ? member.snapshotUrl
        : null;
    final displayLabel = () {
      final n = member.displayName?.trim();
      if (n != null && n.isNotEmpty) return n;
      if (isSelf) return '나';
      return member.userId.length > 8
          ? member.userId.substring(0, 8)
          : member.userId;
    }();

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
          else if (member.publicViewerMode == 'rest')
            _ProfilePlaceholder(
              cs: cs,
              label: displayLabel,
            )
          else
            _Placeholder(cs: cs),

          Positioned(
            top: 6,
            left: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (member.focusScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(160),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withAlpha(60),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 12,
                          color: Colors.amber.shade300,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${member.focusScore}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (member.joinAt != null && !compact)
                  Padding(
                    padding: EdgeInsets.only(
                      top: member.focusScore != null ? 4 : 0,
                    ),
                    child: _JoinElapsedBadge(joinAt: member.joinAt!),
                  ),
              ],
            ),
          ),

          // 상태 텍스트 (상대에게도 보이도록 중앙 오버레이)
          if (member.statusText != null && member.statusText!.trim().isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  member.statusText!.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.15,
                    shadows: [
                      Shadow(
                        blurRadius: 18,
                        color: Colors.black54,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

          if (floatingReaction != null &&
              floatingReaction!.isNotEmpty &&
              floatingReaction == '❤️')
            const _FloatingHeart(),

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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayLabel,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 11 : 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

          if (!isSelf && onChat != null)
            Positioned(
              top: 8,
              right: 8,
              left: 40,
              child: Align(
                alignment: Alignment.topRight,
                child: StudyRoomPeerDmChip(
                  preview: dmPreview,
                  hasUnread: dmHasUnread,
                  onTap: onChat!,
                ),
              ),
            ),
          if (!isSelf)
            Positioned(
              right: 4,
              bottom: 8,
              child: _IconBtn(
                icon: Icons.favorite_outline_rounded,
                tooltip: '응원',
                onTap: () {
                  if (onQuickReact != null) {
                    onQuickReact!('❤️');
                  }
                },
              ),
            ),
        ],
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
