import 'package:flutter/material.dart';

import '../../infra/study_room_controller.dart';
import 'study_room_group_chat_screen.dart';

/// 스터디룸 앱바 우측 — 단체 채팅 진입 (카드 위 말풍선과 동일 스타일).
class StudyRoomGroupChatAppBarButton extends StatelessWidget {
  final StudyRoomController controller;

  const StudyRoomGroupChatAppBarButton({
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
    final preview =
        group.isEmpty ? '' : group.last.content.trim();
    final label = preview.isEmpty ? '단체 채팅' : preview;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Center(
        child: Material(
          color: Colors.black.withAlpha(150),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
