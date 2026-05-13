import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../infra/study_room_controller.dart';
import 'study_room_chat_panel.dart';
import 'study_room_main_stage.dart';

class StudyRoomActiveView extends StatelessWidget {
  final StudyRoomController controller;
  final bool studyCameraSlotActive;
  final ValueListenable<int> engagedMinListenable;

  const StudyRoomActiveView({
    super.key,
    required this.controller,
    required this.studyCameraSlotActive,
    required this.engagedMinListenable,
  });

  @override
  Widget build(BuildContext context) {
    final members = controller.members;
    final selfId = controller.selfId ?? '';

    // 채팅: 메시지 영역은 약 3줄 높이로 고정, 그 이상은 내부 스크롤
    final chatAreaH = StudyRoomChatPanel.totalOuterHeight(context, visibleMessageLines: 3);

    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: members.isEmpty
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
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: StudyRoomMainStage(
                          controller: controller,
                          engagedMinListenable: engagedMinListenable,
                          studyCameraSlotActive: studyCameraSlotActive,
                        ),
                      ),
              ),
              SizedBox(
                height: chatAreaH,
                width: double.infinity,
                child: StudyRoomChatPanel(
                  messages: controller.messages,
                  selfId: selfId,
                  onSendMessage: controller.sendMessage,
                  isFocusMode: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
