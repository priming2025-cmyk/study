import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/supabase/supabase_config.dart';
import '../domain/friend_dm_models.dart';

/// 친구 DM 저장·조회·읽음 처리.
class FriendDmRepository extends ChangeNotifier {
  RealtimeChannel? _channel;
  String? _subscribedUid;

  final List<FriendMessage> _messages = [];
  List<FriendMessage> get messages => List.unmodifiable(_messages);

  String? _activePeerId;
  String? get activePeerId => _activePeerId;
  void setActivePeer(String? peerId) => _activePeerId = peerId;

  void Function(FriendMessage msg)? onIncomingForMe;

  Future<void> ensureSubscribed() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      await _unsubscribe();
      return;
    }
    if (_subscribedUid == uid && _channel != null) return;

    await _unsubscribe();
    _subscribedUid = uid;
    _channel = supabase
        .channel('friend_dm:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friend_messages',
          callback: (payload) {
            final msg = FriendMessage.fromJson(payload.newRecord);
            if (msg.senderId != uid && msg.recipientId != uid) return;
            _messages.add(msg);
            if (msg.recipientId == uid) {
              onIncomingForMe?.call(msg);
            }
            notifyListeners();
          },
        )
        .subscribe();
  }

  Future<void> _unsubscribe() async {
    final ch = _channel;
    _channel = null;
    _subscribedUid = null;
    if (ch != null) {
      try {
        await ch.unsubscribe();
      } catch (e) {
        debugPrint('[FriendDmRepository] unsubscribe: $e');
      }
    }
  }

  Future<List<FriendDmThread>> listThreads() async {
    try {
      final rows = await supabase.rpc('list_friend_dm_threads');
      if (rows is! List) return const [];
      return rows
          .map((e) => FriendDmThread.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[FriendDmRepository] listThreads: $e');
      return const [];
    }
  }

  Future<List<FriendMessage>> fetchThread(String peerId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await supabase
          .from('friend_messages')
          .select()
          .or(
            'and(sender_id.eq.$uid,recipient_id.eq.$peerId),'
            'and(sender_id.eq.$peerId,recipient_id.eq.$uid)',
          )
          .order('created_at', ascending: true)
          .limit(200);
      return rows.map((r) => FriendMessage.fromJson(r)).toList();
    } catch (e) {
      debugPrint('[FriendDmRepository] fetchThread: $e');
      return const [];
    }
  }

  Future<void> sendMessage({
    required String peerId,
    required String content,
    String? replyToMessageId,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    final text = content.trim();
    if (uid == null || text.isEmpty) return;

    await supabase.from('friend_messages').insert({
      'sender_id': uid,
      'recipient_id': peerId,
      'content': text,
      'reply_to_message_id': replyToMessageId,
    });

    // 메시지 전송과 함께 (상대 앱 종료 상태를 포함한) FCM 푸시 발송.
    // 방해 최소화는 수신 측(FCM background handler + StudyActivityGate)에서 처리합니다.
    unawaited(_tryInvokeFriendDmPush(
      recipientUserId: peerId,
      peerDisplayName: await _displayNameOf(peerId),
      senderName: await _displayNameOf(uid),
      body: text,
    ));
  }

  Future<String> _displayNameOf(String userId) async {
    try {
      final row = await supabase
          .from('profiles')
          .select('display_name')
          .eq('id', userId)
          .maybeSingle();
      final v = row?['display_name'];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      return userId.length > 8 ? userId.substring(0, 8) : userId;
    } catch (_) {
      return userId.length > 8 ? userId.substring(0, 8) : userId;
    }
  }

  Future<void> _tryInvokeFriendDmPush({
    required String recipientUserId,
    required String peerDisplayName,
    required String senderName,
    required String body,
  }) async {
    final url = _friendDmPushUrl();
    final token = supabase.auth.currentSession?.accessToken;

    if (url == null) return;
    try {
      final resp = await http.post(
        url,
        headers: {
          'content-type': 'application/json',
          if (token != null) 'authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'recipientUserId': recipientUserId,
          'peerId': recipientUserId,
          'peerDisplayName': peerDisplayName,
          'senderName': senderName,
          'body': body,
        }),
      );
      if (resp.statusCode >= 400) {
        debugPrint('[FriendDmRepository] push invoke failed: ${resp.body}');
      }
    } catch (e) {
      debugPrint('[FriendDmRepository] push invoke error: $e');
    }
  }

  Uri? _friendDmPushUrl() {
    final supaUrl = SupabaseConfig.url;
    if (supaUrl.isEmpty) return null;
    final host = Uri.parse(supaUrl).host; // <ref>.supabase.co
    if (!host.contains('.supabase')) return null;
    final projectRef = host.split('.').first;
    return Uri.parse(
      'https://$projectRef.functions.supabase.co/send_friend_dm_push',
    );
  }

  Future<void> markRead(String peerId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await supabase.from('friend_dm_reads').upsert({
        'user_id': uid,
        'peer_id': peerId,
        'last_read_at': now,
      });
    } catch (e) {
      debugPrint('[FriendDmRepository] markRead: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_unsubscribe());
    super.dispose();
  }
}
