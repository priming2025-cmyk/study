import 'package:flutter/material.dart';

import '../../infra/study_room_controller.dart';
import 'study_room_group_chat_screen.dart';

/// 내 카드 우측 상단 — 단체 채팅 진입 칩.
class StudyRoomGroupChatChip extends StatelessWidget {
  final StudyRoomController controller;

  const StudyRoomGroupChatChip({
    super.key,
    required this.controller,
  });

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyRoomGroupChatScreen(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = controller.roomChatMessages;
    final preview = group.isEmpty ? '' : group.last.content.trim();
    final label = preview.isEmpty ? '단체 채팅' : preview;

    return Material(
      color: Colors.black.withAlpha(150),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
