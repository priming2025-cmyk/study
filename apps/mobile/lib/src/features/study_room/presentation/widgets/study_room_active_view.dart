import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../infra/study_room_controller.dart';
import 'study_room_chat_panel.dart';
import 'study_room_main_stage.dart';

class StudyRoomActiveView extends StatelessWidget {
  final StudyRoomController controller;
  final bool studyCameraSlotActive;
  final bool sessionCameraShared;
  final ValueListenable<int> engagedMinListenable;

  const StudyRoomActiveView({
    super.key,
    required this.controller,
    required this.studyCameraSlotActive,
    required this.sessionCameraShared,
    required this.engagedMinListenable,
  });

  @override
  Widget build(BuildContext context) {
    final members = controller.members;
    final selfId = controller.selfId ?? '';

    // 채팅: 메시지 영역은 약 3줄 높이로 고정, 그 이상은 내부 스크롤
    final chatBaseH = StudyRoomChatPanel.totalOuterHeight(context, visibleMessageLines: 3);
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    // 키보드가 올라와 입력줄만 위로 밀 때 패널 높이에 여유(클리핑 방지)
    final chatAreaH = chatBaseH + keyboardBottom;

    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: MediaQuery.removeViewInsets(
                  removeBottom: true,
                  context: context,
                  // joining 완료 후에는 멤버가 없어도 그리드 표시
                  // (Presence sync 지연으로 members가 빈 상태에서 로딩 화면에 갇히는 문제 방지)
                  child: controller.joining && members.isEmpty
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
                            sessionCameraShared: sessionCameraShared,
                          ),
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
