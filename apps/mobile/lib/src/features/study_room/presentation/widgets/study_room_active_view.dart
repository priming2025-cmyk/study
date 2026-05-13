import 'dart:math' as math;

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

    // 채팅 영역은 화면의 22% (최소 140px, 최대 200px)로 제한해 2×2 그리드가 눌리지 않도록 함
    final mediaH = MediaQuery.sizeOf(context).height;
    final chatAreaH = math.min(200.0, math.max(140.0, mediaH * 0.22));

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
