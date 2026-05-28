import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../infra/study_room_join_link.dart';
import '../../../../core/widgets/share_message_channels.dart';

/// 셋터디 방 초대 — OS 공유 시트로 바로 공유.
abstract final class StudyRoomInviteShare {
  static Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// 중간 시트 없이 바로 카카오/메시지 등 OS 공유.
  static Future<void> share(
    BuildContext context, {
    required String joinCode,
    String? goalText,
  }) async {
    final code = joinCode.trim();
    if (code.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입장코드가 없어요. 방에 입장한 뒤 다시 시도해 주세요.')),
      );
      return;
    }

    final message = studyRoomInviteMessage(joinCode: code, goalText: goalText);
    if (message.trim().isEmpty) return;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: '셋터디 초대',
          sharePositionOrigin: _shareOrigin(context),
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: message));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대 메시지가 복사됐어요')),
      );
    }
  }
}

/// 셋터디 참여 초대 (상세 미리보기가 필요할 때만 시트).
class StudyRoomInviteSheet extends StatelessWidget {
  final String joinCode;
  final String? goalText;

  const StudyRoomInviteSheet({
    super.key,
    required this.joinCode,
    this.goalText,
  });

  /// [shareOnly] true → OS 공유 시트를 바로 엽니다 (친구초대 1탭).
  static Future<void> show(
    BuildContext context, {
    required String joinCode,
    String? goalText,
    bool shareOnly = false,
  }) {
    if (shareOnly) {
      return StudyRoomInviteShare.share(
        context,
        joinCode: joinCode,
        goalText: goalText,
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => StudyRoomInviteSheet(
        joinCode: joinCode,
        goalText: goalText,
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
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),
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
