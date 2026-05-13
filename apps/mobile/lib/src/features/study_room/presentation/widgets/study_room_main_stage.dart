import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../infra/study_room_controller.dart';
import 'study_room_member_card.dart';
import 'study_room_self_live_panel.dart';

/// 2×2 그리드: 왼쪽 위 실시간 나, 나머지 칸은 친구(최대 3). 각 칸은 동일 크기(기존 단일 셀 비율 기준).
class StudyRoomMainStage extends StatelessWidget {
  final StudyRoomController controller;
  final ValueListenable<int> engagedMinListenable;
  final bool studyCameraSlotActive;

  const StudyRoomMainStage({
    super.key,
    required this.controller,
    required this.engagedMinListenable,
    required this.studyCameraSlotActive,
  });

  @override
  Widget build(BuildContext context) {
    final selfId = controller.selfId ?? '';
    final members = controller.members;
    final peers = members.where((m) => m.userId != selfId).take(3).toList();

    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        final rawH = c.maxHeight.isFinite ? c.maxHeight : MediaQuery.sizeOf(context).height * 0.5;
        // 서브픽셀·패딩 오차로 Bottom overflow 나지 않도록 약간 여유
        const layoutSlack = 12.0;
        final budgetH = math.max(80.0, rawH - layoutSlack);

        const gap = 8.0;
        // 타일 세로를 약 1.3배로 키운 뒤, 남는 세로(budget) 안에 맞게 scale로 축소
        const cellHeightScale = 1.3;
        // 2행이 들어갈 수 있는 한 칸 최대 높이(그리드 기준) — 스케일 반영
        final rowMaxH = math.max(100.0, (budgetH - gap) / 2);

        // 단일 ‘내 기기’ 타일과 비슷한 기준, 단 2×2에 맞게 높이 상한을 먼저 제한
        var cellW = (maxW * 0.42).clamp(200.0, 272.0);
        var cellH = cellW * 16 / 9 * cellHeightScale;
        cellH = cellH.clamp(160.0 * cellHeightScale, math.min(rowMaxH, 420.0 * cellHeightScale));

        final gridW = 2 * cellW + gap;
        var gridH = 2 * cellH + gap;
        var scale = 1.0;
        if (gridW > maxW && gridW > 0) scale = math.min(scale, maxW / gridW);
        if (gridH > budgetH && gridH > 0) scale = math.min(scale, budgetH / gridH);
        cellW *= scale;
        cellH *= scale;

        // scale 후에도 부동소수로 1~4px 넘칠 수 있어 한 번 더 맞춤
        gridH = 2 * cellH + gap;
        if (gridH > budgetH && gridH > 0) {
          final hFix = budgetH / gridH;
          cellW *= hFix;
          cellH *= hFix;
        }

        Widget cell(Widget child) => SizedBox(
              width: cellW,
              height: cellH,
              child: child,
            );

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

        return Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cell(
                    StudyRoomSelfLivePanel(
                      width: cellW,
                      height: cellH,
                      cameraSlotActive: studyCameraSlotActive,
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
