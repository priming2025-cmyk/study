import 'package:flutter/material.dart';

import '../../../../core/widgets/sheet_header_bar.dart';
import '../../../../core/widgets/share_message_channels.dart';
import '../../infra/study_room_join_link.dart';

/// 셋터디 참여 초대 시트 (메시지 + 복사 + 채널별 공유).
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
    final code = joinCode.trim().toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeaderBar(
            title: '친구 초대',
            subtitle: '아래 내용을 복사하거나 앱으로 보내세요',
            padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
          ),
          if (code.isEmpty)
            const Text('입장코드가 없어요. 방에 입장한 뒤 다시 시도해 주세요.')
          else
            ShareMessageChannels(
              message: _inviteText,
              copySuccessText: '초대 메시지가 복사됐어요',
            ),
        ],
      ),
    );
  }
}
