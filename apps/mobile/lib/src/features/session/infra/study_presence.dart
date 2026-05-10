import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class PresenceMember {
  final String userId;
  final String subject;
  final DateTime startedAt;

  const PresenceMember({
    required this.userId,
    required this.subject,
    required this.startedAt,
  });
}

class StudyPresence {
  RealtimeChannel? _channel;
  final _members = StreamController<List<PresenceMember>>.broadcast();
  Stream<List<PresenceMember>> get members => _members.stream;

  static const _topic = 'study_presence:global';

  Future<void> join({
    required String selfId,
    required String subject,
    required DateTime startedAt,
  }) async {
    await leave();

    final ch = supabase.channel(
      _topic,
      opts: const RealtimeChannelConfig(
        ack: false,
        self: true,
        key: 'user_id',
        enabled: true,
      ),
    );

    ch.onPresenceSync((_) => _emitMembers(ch));
    ch.onPresenceJoin((_) => _emitMembers(ch));
    ch.onPresenceLeave((_) => _emitMembers(ch));

    _channel = ch;
    ch.subscribe();

    await ch.track({
      'user_id': selfId,
      'subject': subject,
      'started_at': startedAt.toUtc().toIso8601String(),
    });
  }

  Future<void> leave() async {
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      try {
        await ch.untrack();
      } catch (_) {}
      try {
        await ch.unsubscribe();
      } catch (_) {}
    }
  }

  void _emitMembers(RealtimeChannel ch) {
    try {
      final states = ch.presenceState();
      final result = <PresenceMember>[];
      for (final presenceState in states) {
        for (final presence in presenceState.presences) {
          final map = presence.payload;
          final userId =
              (map['user_id'] ?? presenceState.key) as String? ?? presenceState.key;
          final subject = (map['subject'] ?? '') as String? ?? '';
          final startedRaw = (map['started_at'] ?? '') as String? ?? '';
          final startedAt =
              DateTime.tryParse(startedRaw)?.toLocal() ?? DateTime.now();
          result.add(PresenceMember(
            userId: userId,
            subject: subject,
            startedAt: startedAt,
          ));
        }
      }
      _members.add(result);
    } catch (_) {
      _members.add(const []);
    }
  }

  Future<void> dispose() async {
    await leave();
    await _members.close();
  }
}

