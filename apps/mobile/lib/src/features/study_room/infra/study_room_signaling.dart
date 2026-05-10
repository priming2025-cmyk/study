import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/signaling_message.dart';

class StudyRoomSignaling {
  RealtimeChannel? _channel;
  final _controller = StreamController<SignalingMessage>.broadcast();

  Stream<SignalingMessage> get messages => _controller.stream;

  String _topic(String roomId) => 'study_room:$roomId';

  Future<void> connect({required String roomId, required String selfId}) async {
    await disconnect();

    final channel = supabase.channel(
      _topic(roomId),
      opts: const RealtimeChannelConfig(
        ack: false,
        self: false,
        key: '',
        enabled: false,
      ),
    );

    channel.onBroadcast(
      event: 'signal',
      callback: (payload) {
        final raw = payload['payload'];
        if (raw is! Map) return;
        final msg = SignalingMessage.fromJson(raw.cast<String, dynamic>());
        // If message targets someone else, ignore.
        if (msg.to != null && msg.to != selfId) return;
        // Ignore own echo (should not happen with self:false but keep safe)
        if (msg.from == selfId) return;
        _controller.add(msg);
      },
    );

    _channel = channel;
    channel.subscribe();

    await send(
      roomId: roomId,
      message: SignalingMessage(type: 'join', from: selfId, to: null, payload: const {}),
    );
  }

  Future<void> disconnect() async {
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      try {
        await ch.unsubscribe();
      } catch (_) {}
    }
  }

  Future<void> send({required String roomId, required SignalingMessage message}) async {
    final ch = _channel;
    if (ch == null) return;
    await ch.sendBroadcastMessage(
      event: 'signal',
      payload: message.toJson(),
    );
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
  }
}

