import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/widgets/sheet_header_bar.dart';
import '../infra/friend_invite_link.dart';

/// 카카오톡·인스타 등 OS 공유 시트로 친구 초대 링크 보내기.
class FriendInviteSheet extends StatelessWidget {
  const FriendInviteSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const FriendInviteSheet(),
    );
  }

  String _message() => friendInviteMessage();

  Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = _message().trim();
    if (text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('로그인 후 초대 링크를 만들 수 있어요')),
      );
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: '셋터디 친구 초대',
          sharePositionOrigin: _shareOrigin(context),
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('공유할 수 없어서 초대 메시지를 복사했어요. 카톡·인스타에 붙여넣기 하세요'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final link = friendInviteLink();
    final uid = supabase.auth.currentUser?.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeaderBar(
            title: '친구 초대',
            subtitle: '카카오톡·인스타·문자 등 원하는 앱으로 링크를 보내요',
            padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '링크를 열면 앱 설치·친구 추가가 이어져요',
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  uid == null ? '로그인이 필요해요' : link,
                  style: tt.bodySmall?.copyWith(color: cs.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (btnContext) => FilledButton.icon(
              onPressed: uid == null ? null : () => _share(btnContext),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('카톡·인스타 등으로 공유'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: uid == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: _message()));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('초대 메시지가 복사됐어요')),
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
      ),
    );
  }
}
