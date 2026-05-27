import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../infra/study_room_controller.dart';
import 'study_room_chat_panel.dart';
import 'study_room_main_stage.dart';

/// 셋터디 방 입장 후 메인 뷰.
class StudyRoomActiveView extends StatelessWidget {
  final StudyRoomController controller;
  final bool studyCameraSlotActive;
  final ValueListenable<int> engagedMinListenable;
  final bool chatOpen;
  final VoidCallback onToggleChat;

  const StudyRoomActiveView({
    super.key,
    required this.controller,
    required this.studyCameraSlotActive,
    required this.engagedMinListenable,
    required this.chatOpen,
    required this.onToggleChat,
  });

  @override
  Widget build(BuildContext context) {
    final members = controller.members;
    final selfId = controller.selfId ?? '';

    return controller.joining && members.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  '멤버 정보를 불러오는 중…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          )
        : Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: StudyRoomMainStage(
                    controller: controller,
                    engagedMinListenable: engagedMinListenable,
                    studyCameraSlotActive: studyCameraSlotActive,
                    onOpenChat: onToggleChat,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: chatOpen
                    ? StudyRoomChatPanel(
                        key: const ValueKey('chat_open'),
                        messages: controller.messages,
                        selfId: selfId,
                        isFocusMode: false,
                        onSendMessage: controller.sendMessage,
                      )
                    : SafeArea(
                        top: false,
                        child: SizedBox(
                          height: 44,
                          child: Material(
                            color: Theme.of(context).colorScheme.surface,
                            child: InkWell(
                              onTap: onToggleChat,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '채팅 열기',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${controller.messages.length}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
  }
}
