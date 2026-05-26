import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../domain/study_room_models.dart';
import '../../infra/study_room_controller.dart';
import 'study_room_invite_sheet.dart';
import 'study_room_member_card.dart';
import 'study_room_self_live_panel.dart';

/// 인원수에 따른 가변 레이아웃:
///   2명(나+1)   → 1열 2행 세로
///   3명(나+2)   → 1열 3행 세로
///   4명(나+3)   → 2×2
///   5명(나+4)   → 2×2 + 하단 1
///   6명(나+5)   → 2×3
///   7명(나+6)   → 2×3 + 하단 1
///   8명(나+7)   → 2×4
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

  static const double _gap = 6.0;
  // 최대 표시 슬롯 = 자기 자신(1) + 피어 최대(7)
  static const int _maxSlots = 8;

  @override
  Widget build(BuildContext context) {
    final selfId = controller.selfId ?? '';
    final peers = controller.members
        .where((m) => m.userId != selfId)
        .take(_maxSlots - 1)
        .toList();

    // 전체 슬롯 수: 나(1) + 피어 + 빈 슬롯(최대 7칸 채움)
    // 사용자가 보는 총 칸 수는 max(현재인원, 최소표시) 이상으로 할 수 있지만
    // 현 요구사항: 빈 슬롯은 "대기 중/초대" 카드로 채움 (최대 7개 피어 슬롯)
    final totalPeerSlots = peers.length < 7 ? peers.length + 1 : 7; // +1 = 빈 초대 슬롯
    final totalSlots = 1 + totalPeerSlots; // 나 포함

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height * 0.62;

        return _buildGrid(
          context,
          selfId: selfId,
          peers: peers,
          totalSlots: totalSlots,
          maxW: maxW,
          maxH: maxH,
        );
      },
    );
  }

  Widget _buildGrid(
    BuildContext context, {
    required String selfId,
    required List<StudyRoomMember> peers,
    required int totalSlots,
    required double maxW,
    required double maxH,
  }) {
    final gap = _gap;

    // 레이아웃 결정
    final (cols, rows, hasExtra) = _layout(totalSlots);

    // 메인 그리드 셀 크기
    final mainRows = hasExtra ? rows - 1 : rows;
    final cellW = (maxW - gap * (cols - 1)) / cols;
    final totalGapH = gap * (rows - 1);
    final cellH = (maxH - totalGapH) / rows;

    // 전체 슬롯 목록: [나, peer0, peer1, ...]
    final slots = <_Slot>[
      _Slot.self(),
      for (var i = 0; i < totalPeerSlots(peers); i++)
        i < peers.length ? _Slot.peer(peers[i]) : _Slot.empty(),
    ];

    Widget buildCell(_Slot slot, double w, double h) => SizedBox(
          width: w,
          height: h,
          child: _slotWidget(context, slot, selfId, w, h),
        );

    if (cols == 1) {
      // 세로 1열
      return SizedBox(
        width: maxW,
        height: maxH,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < slots.length; r++) ...[
              if (r > 0) SizedBox(height: gap),
              buildCell(slots[r], maxW, cellH),
            ],
          ],
        ),
      );
    }

    // 2열 그리드
    final mainSlots =
        hasExtra ? slots.take(slots.length - 1).toList() : slots;
    final extraSlot = hasExtra ? slots.last : null;

    return SizedBox(
      width: maxW,
      height: maxH,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < mainRows; r++) ...[
            if (r > 0) SizedBox(height: gap),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildCell(mainSlots[r * 2], cellW, cellH),
                SizedBox(width: gap),
                buildCell(mainSlots[r * 2 + 1], cellW, cellH),
              ],
            ),
          ],
          if (extraSlot != null) ...[
            SizedBox(height: gap),
            buildCell(extraSlot, maxW, cellH),
          ],
        ],
      ),
    );
  }

  int totalPeerSlots(List<StudyRoomMember> peers) =>
      peers.length < 7 ? peers.length + 1 : 7;

  /// (열 수, 행 수, 하단 단독 셀 여부)
  (int cols, int rows, bool hasExtra) _layout(int totalSlots) {
    return switch (totalSlots) {
      <= 1 => (1, 1, false),
      2 => (1, 2, false),
      3 => (1, 3, false),
      4 => (2, 2, false),
      5 => (2, 3, true),  // 2×2 + 하단 1
      6 => (2, 3, false),
      7 => (2, 4, true),  // 2×3 + 하단 1
      _ => (2, 4, false), // 8명
    };
  }

  Widget _slotWidget(
    BuildContext context,
    _Slot slot,
    String selfId,
    double w,
    double h,
  ) {
    if (slot.isSelf) {
      return StudyRoomSelfLivePanel(
        controller: controller,
        width: w,
        height: h,
        cameraSlotActive: studyCameraSlotActive,
        engagedMinListenable: engagedMinListenable,
      );
    }
    if (slot.isEmpty) {
      return _EmptyPeerSlot(
        roomId: controller.roomId ?? '',
        onTap: controller.roomId == null
            ? null
            : () => StudyRoomInviteSheet.show(
                  context,
                  roomId: controller.roomId!,
                ),
      );
    }
    final m = slot.member!;
    return StudyRoomMemberCard(
      member: m,
      isSelf: false,
      compact: true,
      floatingReaction: controller.reactionEmojiFor(m.userId),
      onQuickReact: (emoji) =>
          controller.sendQuickReaction(targetUserId: m.userId, emoji: emoji),
    );
  }
}

// ── 슬롯 모델 ────────────────────────────────────────────────
class _Slot {
  final bool isSelf;
  final bool isEmpty;
  final StudyRoomMember? member;

  const _Slot._({required this.isSelf, required this.isEmpty, this.member});

  factory _Slot.self() => const _Slot._(isSelf: true, isEmpty: false);
  factory _Slot.peer(StudyRoomMember m) =>
      _Slot._(isSelf: false, isEmpty: false, member: m);
  factory _Slot.empty() => const _Slot._(isSelf: false, isEmpty: true);
}

// ── 빈 슬롯: + 친구초대 ──────────────────────────────────────
class _EmptyPeerSlot extends StatelessWidget {
  final String roomId;
  final VoidCallback? onTap;

  const _EmptyPeerSlot({required this.roomId, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: cs.surfaceContainerHighest.withAlpha(110),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cs.outlineVariant.withAlpha(80),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.primary.withAlpha(80),
                    width: 1.5,
                  ),
                ),
                child: Icon(Icons.add, color: cs.primary, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                '친구초대',
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
