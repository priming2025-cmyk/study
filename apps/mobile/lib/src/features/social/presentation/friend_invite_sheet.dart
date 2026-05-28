import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/widgets/sheet_header_bar.dart';
import '../../../core/widgets/share_message_channels.dart';
import '../infra/friend_invite_link.dart';

/// 카카오톡·인스타 등으로 친구 초대 링크 보내기.
class FriendInviteSheet extends StatelessWidget {
  const FriendInviteSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const FriendInviteSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = supabase.auth.currentUser?.id;

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
          if (uid == null)
            const Text('로그인 후 초대 링크를 만들 수 있어요')
          else
            ShareMessageChannels(message: friendInviteMessage()),
        ],
      ),
    );
  }
}
