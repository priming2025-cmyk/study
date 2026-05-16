import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../infra/study_room_controller.dart';
import 'study_room_member_card.dart';
import 'study_room_self_live_panel.dart';

/// 2×2 그리드: 왼쪽 위 = 내 화면, 나머지 3칸 = 친구(최대 3명).
/// 현재 UI에서 남은 공간을 최대한 활용하여 꽉 채워 표시합니다.
class StudyRoomMainStage extends StatelessWidget {
  final StudyRoomController controller;
  final ValueListenable<int> engagedMinListenable;
  final bool studyCameraSlotActive;
  final bool sessionCameraShared;

  const StudyRoomMainStage({
    super.key,
    required this.controller,
    required this.engagedMinListenable,
    required this.studyCameraSlotActive,
    required this.sessionCameraShared,
  });

  @override
  Widget build(BuildContext context) {
    final selfId = controller.selfId ?? '';
    final members = controller.members;
    final peers = members.where((m) => m.userId != selfId).take(3).toList();

    const gap = 8.0;

    Widget peerSlot(int i) {
      if (i >= peers.length) return const _EmptyPeerSlot();
      final m = peers[i];
      return StudyRoomMemberCard(
        member: m,
        isSelf: false,
        compact: true,
        floatingReaction: controller.reactionEmojiFor(m.userId),
        onQuickReact: (emoji) => controller.sendQuickReaction(
          targetUserId: m.userId,
          emoji: emoji,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * 0.6;

        // 가용 공간을 2×2로 균등 분할하여 overflow 없이 꽉 채움
        final cellW = ((maxW - gap) / 2).clamp(0.0, double.infinity);
        final cellH = ((maxH - gap) / 2).clamp(0.0, double.infinity);

        Widget cell(Widget child) => SizedBox(
              width: cellW,
              height: cellH,
              child: child,
            );

        return SizedBox(
          width: maxW,
          height: maxH,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  cell(
                    StudyRoomSelfLivePanel(
                      width: cellW,
                      height: cellH,
                      cameraSlotActive: studyCameraSlotActive,
                      sessionCameraShared: sessionCameraShared,
                      engagedMinListenable: engagedMinListenable,
                    ),
                  ),
                  const SizedBox(width: gap),
                  cell(peerSlot(0)),
                ],
              ),
              const SizedBox(height: gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  cell(peerSlot(1)),
                  const SizedBox(width: gap),
                  cell(peerSlot(2)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyPeerSlot extends StatelessWidget {
  const _EmptyPeerSlot();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: cs.surfaceContainerHighest.withAlpha(120),
      child: Center(
        child: Text(
          '대기 중',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
