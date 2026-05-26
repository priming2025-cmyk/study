import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../infra/study_room_controller.dart';
import 'study_room_main_stage.dart';

/// 셋터디 방 입장 후 메인 뷰.
/// 채팅 패널 없이 그리드 전체 화면 + 셀 내 아이콘으로 채팅/좋아요/뷰어 접근.
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
        : Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: StudyRoomMainStage(
              controller: controller,
              engagedMinListenable: engagedMinListenable,
              studyCameraSlotActive: studyCameraSlotActive,
            ),
          );
  }
}
