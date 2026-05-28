import 'package:flutter/material.dart';

import '../../infra/study_room_join_link.dart';
import '../../../../core/widgets/share_message_channels.dart';

/// 셋터디 참여 초대 — 텍스트 공유 스타일.
class StudyRoomInviteSheet extends StatelessWidget {
  final String joinCode;
  final String? goalText;
  final bool shareOnly;

  const StudyRoomInviteSheet({
    super.key,
    required this.joinCode,
    this.goalText,
    this.shareOnly = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String joinCode,
    String? goalText,
    bool shareOnly = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => StudyRoomInviteSheet(
        joinCode: joinCode,
        goalText: goalText,
        shareOnly: shareOnly,
      ),
    );
  }

  String get _inviteText => studyRoomInviteMessage(
        joinCode: joinCode,
        goalText: goalText,
      );

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final code = joinCode.trim().toUpperCase();
        final goal = goalText?.trim();
    final line1 = goal != null && goal.isNotEmpty
        ? '우리 같이 공부하자! (목표: $goal)'
        : '우리 같이 공부하자!';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '텍스트 공유',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          if (code.isEmpty)
            const Text('입장코드가 없어요. 방에 입장한 뒤 다시 시도해 주세요.')
          else
            ShareMessageChannels(
              message: _inviteText,
              previewLine1: line1,
              previewLine2: '입장코드: $code',
              copyMessageSuccessText: '초대 메시지가 복사됐어요',
            ),
        ],
      ),
    );
  }
}
