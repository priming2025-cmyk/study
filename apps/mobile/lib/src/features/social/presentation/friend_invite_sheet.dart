import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_client.dart';
import '../infra/friend_invite_link.dart';
import '../../../core/widgets/share_message_channels.dart';

/// 친구 초대 — 텍스트 공유 스타일.
class FriendInviteSheet extends StatelessWidget {
  const FriendInviteSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const FriendInviteSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final uid = supabase.auth.currentUser?.id;
    final message = uid == null ? '' : friendInviteMessage();

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
          if (uid == null)
            const Text('로그인 후 초대 링크를 만들 수 있어요')
          else
            ShareMessageChannels(
              message: message,
              previewLine1: '셋터디에서 같이 공부해요!',
              previewLine2: '친구 추가 링크',
              copyMessageSuccessText: '초대 메시지가 복사됐어요',
            ),
        ],
      ),
    );
  }
}
