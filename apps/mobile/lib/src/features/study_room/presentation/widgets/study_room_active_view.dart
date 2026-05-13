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

    // 입력은 1줄로 얇게 두고, 메시지 리스트에 약 3줄 분량 이상 확보 (전체 높이는 입력 절약분 반영)
    final mediaH = MediaQuery.sizeOf(context).height;
    final chatAreaH = math.min(248.0, math.max(176.0, mediaH * 0.30));

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
