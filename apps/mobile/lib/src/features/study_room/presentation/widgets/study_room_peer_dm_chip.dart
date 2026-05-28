import 'package:flutter/material.dart';

/// 친구 카드 우측 상단 — DM 미리보기 칩 (단체 채팅 칩과 동일 스타일).
class StudyRoomPeerDmChip extends StatelessWidget {
  final String? preview;
  final bool hasUnread;
  final VoidCallback onTap;

  const StudyRoomPeerDmChip({
    super.key,
    required this.preview,
    required this.hasUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = (preview ?? '').trim();
    final label = text.isEmpty ? '채팅하기' : text;

    return Material(
      color: hasUnread
          ? Theme.of(context).colorScheme.primary.withAlpha(220)
          : Colors.black.withAlpha(150),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_rounded,
                size: 14,
                color: Colors.white.withAlpha(hasUnread ? 255 : 220),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withAlpha(hasUnread ? 255 : 230),
                    fontSize: 11,
                    fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
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
