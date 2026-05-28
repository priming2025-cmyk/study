import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/study/study_activity_gate.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/friend_dm_providers.dart';
import '../data/friend_dm_repository.dart';
import '../domain/friend_dm_models.dart';
import '../infra/dm_notification_stub.dart'
    if (dart.library.html) '../infra/dm_notification_web.dart'
    if (dart.library.io) '../infra/dm_notification_io.dart' as notify;
import 'friend_dm_chat_screen.dart';

/// 앱 전역 친구 DM Realtime + (공부 중이 아닐 때) 로컬 알림.
class FriendDmListener extends ConsumerStatefulWidget {
  final Widget child;

  const FriendDmListener({super.key, required this.child});

  @override
  ConsumerState<FriendDmListener> createState() => _FriendDmListenerState();
}

class _FriendDmListenerState extends ConsumerState<FriendDmListener> {
  StreamSubscription<AuthState>? _authSub;
  FriendDmRepository? _repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
    _authSub = supabase.auth.onAuthStateChange.listen((_) => _boot());
  }

  Future<void> _boot() async {
    if (!mounted) return;
    final repo = ref.read(friendDmRepositoryProvider);
    _repo?.removeListener(_onRepo);
    _repo?.onIncomingForMe = null;
    _repo = repo;
    repo.onIncomingForMe = _onIncoming;
    repo.addListener(_onRepo);
    await notify.dmNotificationInit();
    await repo.ensureSubscribed();
  }

  void _onRepo() {
    if (mounted) ref.invalidate(friendDmThreadsProvider);
  }

  Future<void> _onIncoming(FriendMessage msg) async {
    if (StudyActivityGate.isStudying) return;
    final active = ref.read(friendDmActivePeerProvider);
    if (active == msg.senderId) return;

    final threads = await ref.read(friendDmRepositoryProvider).listThreads();
    FriendDmThread? thread;
    for (final t in threads) {
      if (t.peerId == msg.senderId) {
        thread = t;
        break;
      }
    }
    final name = thread?.peerDisplayName ??
        (msg.senderId.length > 8
            ? msg.senderId.substring(0, 8)
            : msg.senderId);

    await notify.dmNotificationShow(
      title: name,
      body: msg.content,
      payload: msg.senderId,
    );
    if (mounted) ref.invalidate(friendDmThreadsProvider);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _repo?.removeListener(_onRepo);
    _repo?.onIncomingForMe = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 셋터디 탭 등에서 친구 DM 화면 열기.
void openFriendDmChat(
  BuildContext context,
  WidgetRef ref, {
  required String peerId,
  required String peerDisplayName,
  String? peerAvatarUrl,
}) {
  ref.read(friendDmActivePeerProvider.notifier).state = peerId;
  Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          builder: (_) => FriendDmChatScreen(
            peerId: peerId,
            peerDisplayName: peerDisplayName,
            peerAvatarUrl: peerAvatarUrl,
          ),
        ),
      )
      .whenComplete(() {
    ref.read(friendDmActivePeerProvider.notifier).state = null;
    ref.invalidate(friendDmThreadsProvider);
  });
}
