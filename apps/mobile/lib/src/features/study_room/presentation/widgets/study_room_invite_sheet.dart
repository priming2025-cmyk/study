import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/widgets/sheet_header_bar.dart';
import '../../infra/study_room_join_link.dart';

/// 셋터디 참여 초대 시트 (짧은 입장코드 + 공유).
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

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('입장코드가 복사됐어요')),
    );
  }

  Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _shareInvite(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = _inviteText.trim();
    if (text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('공유할 초대 내용이 없어요.')),
      );
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: '셋터디 초대',
          sharePositionOrigin: _shareOrigin(context),
          mailToFallbackEnabled: true,
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('공유할 수 없어서 초대 메시지를 복사했어요.')),
      );
    }
  }

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
          const SheetHeaderBar(
            title: '친구 초대',
            padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
          ),
          const SizedBox(height: 8),
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
                const SizedBox(height: 12),
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
                    const Spacer(),
                    TextButton.icon(
                      onPressed: code.isEmpty
                          ? null
                          : () => _copyCode(context, code),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('복사하기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Builder(
            builder: (btnContext) => FilledButton.icon(
              onPressed: () => _shareInvite(btnContext),
              icon: const Icon(Icons.share_rounded),
              label: const Text('공유하기'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (!shareOnly) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _inviteText));
                if (!context.mounted) return;
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
