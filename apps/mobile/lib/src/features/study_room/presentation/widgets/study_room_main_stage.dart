import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../domain/study_room_models.dart';
import '../../infra/study_room_controller.dart';
import 'study_room_invite_sheet.dart';
import 'study_room_member_card.dart';
import 'study_room_self_live_panel.dart';

/// 인원수에 따른 가변 레이아웃 (Flutter 공통 — iOS · Android · Web 동일):
///   2명 → 1열 세로 (나, 1)
///   3명 → 1열 세로 (나, 2)
///   4명 → 2×2 (나 포함)
///   5명 → 맨 위 나(전체 너비) + 아래 2×2
///   6명 → 2×3 (나 포함)
///   7명 → 맨 위 나(전체 너비) + 아래 2×3
///   8명 → 2×4 (나 포함)
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

  @override
  Widget build(BuildContext context) {
    final selfId = controller.selfId ?? '';
    final maxSlots = (controller.maxPeers ?? 8).clamp(2, 8);
    final availablePeerSlots = maxSlots - 1;

    final peers = controller.members
        .where((m) => m.userId != selfId)
        .take(availablePeerSlots)
        .toList();

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
          peerSlotsCount: availablePeerSlots,
          totalSlots: maxSlots,
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
    required int peerSlotsCount,
    required int totalSlots,
    required double maxW,
    required double maxH,
  }) {
    final gap = _gap;

    final peerSlots = <_Slot>[
      for (var i = 0; i < peerSlotsCount; i++)
        i < peers.length ? _Slot.peer(peers[i]) : _Slot.empty(),
    ];

    Widget buildCell(_Slot slot, double w, double h) => SizedBox(
          width: w,
          height: h,
          child: _slotWidget(context, slot, selfId, w, h),
        );

    // 5명·7명: 맨 위 나(가로 전체) + 아래 2열 그리드
    if (_selfOnTopLayout(totalSlots)) {
      final gridRows = totalSlots == 5 ? 2 : 3;
      final rowCount = 1 + gridRows;
      final rowH = (maxH - gap * (rowCount - 1)) / rowCount;
      final cellW = (maxW - gap) / 2;

      return SizedBox(
        width: maxW,
        height: maxH,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildCell(_Slot.self(), maxW, rowH),
            for (var r = 0; r < gridRows; r++) ...[
              SizedBox(height: gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildCell(peerSlots[r * 2], cellW, rowH),
                  SizedBox(width: gap),
                  buildCell(peerSlots[r * 2 + 1], cellW, rowH),
                ],
              ),
            ],
          ],
        ),
      );
    }

    final (cols, rows, hasExtra) = _layout(totalSlots);
    final mainRows = hasExtra ? rows - 1 : rows;
    final cellW = (maxW - gap * (cols - 1)) / cols;
    final totalGapH = gap * (rows - 1);
    final cellH = (maxH - totalGapH) / rows;

    final slots = <_Slot>[
      _Slot.self(),
      ...peerSlots,
    ];

    if (cols == 1) {
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

  bool _selfOnTopLayout(int totalSlots) =>
      totalSlots == 5 || totalSlots == 7;

  /// (열 수, 행 수, 하단 단독 셀 여부) — 5·7명은 [_selfOnTopLayout] 사용
  (int cols, int rows, bool hasExtra) _layout(int totalSlots) {
    return switch (totalSlots) {
      <= 1 => (1, 1, false),
      2 => (1, 2, false),
      3 => (1, 3, false),
      4 => (2, 2, false),
      5 => (2, 2, false),
      6 => (2, 3, false),
      7 => (2, 3, false),
      _ => (2, 4, false),
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
        onTap: controller.joinCode == null
            ? null
            : () => StudyRoomInviteSheet.show(
                  context,
                  joinCode: controller.joinCode!,
                  goalText: controller.goalText,
                  shareOnly: true,
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

class _EmptyPeerSlot extends StatelessWidget {
  final VoidCallback? onTap;

  const _EmptyPeerSlot({this.onTap});

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
