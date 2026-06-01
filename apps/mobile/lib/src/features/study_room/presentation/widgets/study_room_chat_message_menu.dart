import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/study_room_models.dart';

/// 카카오톡형 메시지 길게 누르기 메뉴.
Future<StudyRoomMessageAction?> showStudyRoomMessageActionSheet(
  BuildContext context, {
  required StudyRoomMessage message,
  required String senderLabel,
}) {
  return showModalBottomSheet<StudyRoomMessageAction>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                senderLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            _ActionTile(
              icon: Icons.content_copy_rounded,
              label: '복사',
              onTap: () => Navigator.pop(ctx, StudyRoomMessageAction.copy),
            ),
            _ActionTile(
              icon: Icons.reply_rounded,
              label: '답장',
              onTap: () => Navigator.pop(ctx, StudyRoomMessageAction.reply),
            ),
            _ActionTile(
              icon: Icons.ios_share_rounded,
              label: '공유',
              onTap: () => Navigator.pop(ctx, StudyRoomMessageAction.share),
            ),
            _ActionTile(
              icon: Icons.campaign_outlined,
              label: '공지',
              onTap: () => Navigator.pop(ctx, StudyRoomMessageAction.notice),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

enum StudyRoomMessageAction { copy, reply, share, notice }

Future<void> handleStudyRoomMessageAction({
  required BuildContext context,
  required StudyRoomMessageAction action,
  required StudyRoomMessage message,
  required String senderLabel,
  void Function(StudyRoomMessage message)? onReply,
  void Function(StudyRoomMessage message)? onNotice,
}) async {
  final text = message.content.trim();
  if (text.isEmpty) return;

  switch (action) {
    case StudyRoomMessageAction.copy:
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('복사했어요'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    case StudyRoomMessageAction.reply:
      onReply?.call(message);
    case StudyRoomMessageAction.share:
      await Share.share(text, subject: '$senderLabel · 셋터디');
    case StudyRoomMessageAction.notice:
      onNotice?.call(message);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공지로 등록했어요'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

/// 단체 채팅 상단 공지 배너.
class StudyRoomGroupNoticeBanner extends StatelessWidget {
  final StudyRoomMessage notice;
  final String senderLabel;
  final VoidCallback? onClear;

  const StudyRoomGroupNoticeBanner({
    super.key,
    required this.notice,
    required this.senderLabel,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.campaign_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '공지 · $senderLabel',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notice.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onPrimaryContainer,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClear,
                tooltip: '공지 내리기',
              ),
          ],
        ),
      ),
    );
  }
}
