import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../infra/study_room_join_link.dart';

/// 셋터디 참여 초대 시트 (짧은 입장코드 + 딥링크).
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

  String get _link => studyRoomJoinLink(joinCode);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final code = joinCode.trim().toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '친구 초대',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '우리 같이 공부하자!',
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (goalText != null && goalText!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '목표: ${goalText!.trim()}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '입장코드 ',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Text(
                      code,
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        letterSpacing: 2,
                      ),
                    ),
                    if (!shareOnly) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.copy_rounded,
                            size: 18, color: cs.primary),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('입장코드가 복사됐어요')),
                          );
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '링크를 누르면 앱에서 바로 입장할 수 있어요',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _link,
                  style: tt.bodySmall?.copyWith(
                    color: cs.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await SharePlus.instance.share(
                  ShareParams(text: _inviteText, subject: 'Setudy 셋터디 초대'),
                );
              } catch (e) {
                // 공유가 막힌 환경에서도 최소한 메시지 텍스트는 전달 가능하게 함.
                Clipboard.setData(ClipboardData(text: _inviteText));
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('공유에 실패했어요. 초대 메시지를 복사했어요.'),
                    action: SnackBarAction(
                      label: '확인',
                      onPressed: () {},
                    ),
                  ),
                );
              } finally {
                if (context.mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.share_rounded),
            label: const Text('공유하기'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (!shareOnly) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _inviteText));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('초대 메시지가 복사됐어요!')),
                );
              },
              icon: const Icon(Icons.content_copy_rounded),
              label: const Text('메시지 복사'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
