import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/study_room_models.dart';
import 'room_snapshot.dart';
import 'study_room_ambient_player.dart';

const _snapshotBucket = 'study-snapshots';
const _snapshotInterval = Duration(seconds: 60);

class _ReactionEntry {
  final StudyRoomReactionOverlay overlay;
  final Timer timer;

  _ReactionEntry({required this.overlay, required this.timer});
}

class StudyRoomController extends ChangeNotifier {
  StudyRoomController() : _ambient = StudyRoomAmbientPlayer();

  final RoomSnapshot _snapshot = RoomSnapshot();
  final StudyRoomAmbientPlayer _ambient;

  String? roomId;
  String? _selfId;
  String? get selfId => _selfId;
  String? selfSnapshotUrl;

  String? roomOwnerId;
  bool get isRoomHost =>
      roomOwnerId != null && _selfId != null && roomOwnerId == _selfId;

  List<StudyRoomMember> _members = const [];
  List<StudyRoomMember> get members => _members;

  List<StudyRoomMessage> _messages = [];
  List<StudyRoomMessage> get messages => _messages;

  bool joining = false;
  String? error;

  RealtimeChannel? _presenceChannel;
  RealtimeChannel? _messageChannel;
  Timer? _snapshotTimer;
  bool _snapshotInitialized = false;

  String _selfGoalText = '';
  late DateTime _selfJoinAtUtc;
  String _selfStatus = 'focus';
  String? _selfSubjectName;

  int _selfPublicLevel = 1;
  String? _selfPublicTitleKo;

  final Map<String, _ReactionEntry> _reactions = {};

  StudyRoomAmbientPlayer get ambient => _ambient;

  StudyRoomMember? get hostMember {
    final oid = roomOwnerId;
    if (oid == null) return null;
    for (final m in _members) {
      if (m.userId == oid) return m;
    }
    return null;
  }

  String? reactionEmojiFor(String userId) => _reactions[userId]?.overlay.emoji;

  // ── 방 만들기 ──────────────────────────────────────────────────────────────

  Future<String> createRoom({required String name}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('로그인이 필요합니다.');

    await _ensureProfile(userId);

    final row = await supabase
        .from('study_rooms')
        .insert({
          'owner_id': userId,
          'name': name.trim().isEmpty ? '스터디방' : name.trim(),
          'max_peers': 4,
        })
        .select('id')
        .single();

    return '${row['id']}';
  }

  // ── 방 입장 ──────────────────────────────────────────────────────────────

  Future<void> joinRoom({required String roomId, String goalText = ''}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('로그인이 필요합니다.');

    joining = true;
    error = null;
    notifyListeners();

    try {
      await _ensureProfile(userId);

      this.roomId = roomId;
      _selfId = userId;
      _messages = [];
      _selfGoalText = goalText.trim();
      _selfJoinAtUtc = DateTime.now().toUtc();
      _selfStatus = 'focus';

      final roomRow = await supabase
          .from('study_rooms')
          .select('owner_id')
          .eq('id', roomId)
          .maybeSingle();
      roomOwnerId = roomRow?['owner_id'] as String?;

      await _loadSelfRpgForPresence();

      await supabase.from('study_room_members').upsert(
        {'room_id': roomId, 'user_id': userId, 'left_at': null},
        onConflict: 'room_id,user_id',
      );

      await _fetchMessages(roomId);
      await _joinMessageChannel(roomId);

      if (!_snapshotInitialized) {
        await _snapshot.initialize();
        _snapshotInitialized = true;
      }

      final url = await _uploadSnapshot(roomId: roomId, userId: userId);
      selfSnapshotUrl = url;

      await _joinPresence(roomId: roomId, userId: userId, snapshotUrl: url);

      _snapshotTimer?.cancel();
      _snapshotTimer = Timer.periodic(_snapshotInterval, (_) async {
        final rid = this.roomId;
        final uid = _selfId;
        if (rid == null || uid == null) return;
        final newUrl = await _uploadSnapshot(roomId: rid, userId: uid);
        if (newUrl != null) {
          selfSnapshotUrl = newUrl;
          await _trackSelfFull(snapshotUrl: newUrl);
          notifyListeners();
        }
      });
    } catch (e) {
      error = '방 입장 실패: $e';
      debugPrint('[StudyRoomController] joinRoom error: $e');
    } finally {
      joining = false;
      notifyListeners();
    }
  }

  // ── 나가기 ────────────────────────────────────────────────────────────────

  Future<void> leave() async {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;

    for (final e in _reactions.values) {
      e.timer.cancel();
    }
    _reactions.clear();

    await _ambient.stop();

    final rid = roomId;
    final uid = _selfId;

    roomId = null;
    roomOwnerId = null;
    _selfId = null;
    _members = const [];
    _messages = [];
    selfSnapshotUrl = null;

    if (rid != null && uid != null) {
      try {
        await supabase
            .from('study_room_members')
            .update({'left_at': DateTime.now().toUtc().toIso8601String()})
            .eq('room_id', rid)
            .eq('user_id', uid);
      } catch (_) {}
    }

    await _leaveMessageChannel();
    await _leavePresence();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_shutdown());
    super.dispose();
  }

  Future<void> _shutdown() async {
    await leave();
    await _ambient.dispose();
    await _snapshot.dispose();
  }

  // ── 메시지 ─────────────────────────────────────────────────────────────────

  Future<void> sendMessage(String content) async {
    final rid = roomId;
    final uid = _selfId;
    if (rid == null || uid == null || content.trim().isEmpty) return;

    try {
      await supabase.from('study_room_messages').insert({
        'room_id': rid,
        'user_id': uid,
        'content': content.trim(),
      });
    } catch (e) {
      debugPrint('[StudyRoomController] sendMessage error: $e');
    }
  }

  /// 방장을 다른 참가자에게 넘깁니다. (DB RPC, RLS 우회)
  Future<String?> transferRoomHostTo(String newOwnerUserId) async {
    final rid = roomId;
    if (rid == null || !isRoomHost) return '방장만 위임할 수 있어요.';
    if (newOwnerUserId == _selfId) return null;
    try {
      await supabase.rpc(
        'transfer_study_room_host',
        params: {
          'p_room_id': rid,
          'p_new_owner_id': newOwnerUserId,
        },
      );
      final row = await supabase.from('study_rooms').select('owner_id').eq('id', rid).single();
      roomOwnerId = row['owner_id'] as String?;
      await _trackSelfFull();
      notifyListeners();
      return null;
    } catch (e) {
      return '위임 실패: $e';
    }
  }

  // ── 리액션 ─────────────────────────────────────────────────────────────────

  Future<void> sendQuickReaction({
    required String targetUserId,
    required String emoji,
  }) async {
    if (targetUserId == _selfId) return;
    final ch = _presenceChannel;
    if (ch == null) return;
    try {
      await ch.sendBroadcastMessage(
        event: 'reaction',
        payload: {
          'target_user_id': targetUserId,
          'emoji': emoji,
          'from_user_id': _selfId,
        },
      );
    } catch (e) {
      debugPrint('[StudyRoomController] sendQuickReaction: $e');
    }
  }

  // ── 내부: Presence ───────────────────────────────────────────────────────

  Future<void> _trackSelfFull({String? snapshotUrl}) async {
    final ch = _presenceChannel;
    final uid = _selfId;
    if (ch == null || uid == null) return;

    final snap = snapshotUrl ?? selfSnapshotUrl ?? '';
    final payload = <String, dynamic>{
      'user_id': uid,
      'snapshot_url': snap,
      'snapshot_at': DateTime.now().toUtc().toIso8601String(),
      'status': _selfStatus,
      'subject_name': _selfSubjectName,
      'goal_text': _selfGoalText,
      'join_at': _selfJoinAtUtc.toIso8601String(),
    };

    payload['public_level'] = _selfPublicLevel;
    payload['public_title_ko'] = _selfPublicTitleKo ?? '';

    try {
      await ch.track(payload);
    } catch (e) {
      debugPrint('[StudyRoomController] track: $e');
    }
  }

  void _onReactionBroadcast(Map<String, dynamic> payload) {
    final target = payload['target_user_id'] as String?;
    final emoji = payload['emoji'] as String?;
    if (target == null || emoji == null) return;

    _reactions[target]?.timer.cancel();
    _reactions.remove(target);

    final overlay = StudyRoomReactionOverlay(
      emoji: emoji,
      receivedAt: DateTime.now(),
    );
    final timer = Timer(const Duration(milliseconds: 2400), () {
      _reactions.remove(target);
      notifyListeners();
    });
    _reactions[target] = _ReactionEntry(overlay: overlay, timer: timer);
    notifyListeners();
  }

  Future<void> _fetchMessages(String roomId) async {
    try {
      final rows = await supabase
          .from('study_room_messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: true)
          .limit(100);
      _messages = rows.map((r) => StudyRoomMessage.fromJson(r)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('[StudyRoomController] fetch messages error: $e');
    }
  }

  Future<void> _joinMessageChannel(String roomId) async {
    await _leaveMessageChannel();
    _messageChannel = supabase
        .channel('messages:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'study_room_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            final newMsg = StudyRoomMessage.fromJson(payload.newRecord);
            _messages.add(newMsg);
            notifyListeners();
          },
        )
        .subscribe();
  }

  Future<void> _leaveMessageChannel() async {
    final ch = _messageChannel;
    _messageChannel = null;
    if (ch != null) {
      try {
        await ch.unsubscribe();
      } catch (_) {}
    }
  }

  Future<String?> _uploadSnapshot({
    required String roomId,
    required String userId,
  }) async {
    try {
      final bytes = await _snapshot.capture();
      if (bytes == null) return null;

      final path = '$roomId/$userId.jpg';
      await supabase.storage.from(_snapshotBucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final base = supabase.storage.from(_snapshotBucket).getPublicUrl(path);
      return '$base?t=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('[StudyRoomController] snapshot upload error: $e');
      return null;
    }
  }

  Future<void> _joinPresence({
    required String roomId,
    required String userId,
    String? snapshotUrl,
  }) async {
    await _leavePresence();

    final ch = supabase.channel(
      'study_room:$roomId',
      opts: const RealtimeChannelConfig(
        ack: false,
        self: true,
        key: 'user_id',
        enabled: true,
      ),
    );

    ch
      ..onPresenceSync((_) => _refreshMembers(ch, userId))
      ..onPresenceJoin((_) => _refreshMembers(ch, userId))
      ..onPresenceLeave((_) => _refreshMembers(ch, userId))
      ..onBroadcast(
        event: 'reaction',
        callback: _onReactionBroadcast,
      );

    _presenceChannel = ch;

    final joined = Completer<void>();
    ch.subscribe((status, err) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (!joined.isCompleted) joined.complete();
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        if (!joined.isCompleted) {
          joined.completeError(err ?? StateError('Presence 연결 실패'));
        }
      }
    });

    try {
      await joined.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      debugPrint('[StudyRoomController] presence connect failed');
    }

    await _trackSelfFull(snapshotUrl: snapshotUrl);
  }

  void _refreshMembers(RealtimeChannel ch, String selfId) {
    final states = ch.presenceState();
    final result = <StudyRoomMember>[];

    for (final state in states) {
      for (final presence in state.presences) {
        final p = presence.payload;
        final uid = (p['user_id'] ?? state.key) as String? ?? state.key;
        final snapshotUrl = p['snapshot_url'] as String?;
        final snapshotAtRaw = p['snapshot_at'] as String?;
        final status = p['status'] as String?;
        final subjectName = p['subject_name'] as String?;
        final goalText = p['goal_text'] as String?;
        final joinAtRaw = p['join_at'] as String?;
        final publicLevelRaw = p['public_level'];
        final publicTitleKo = p['public_title_ko'] as String?;

        DateTime? snapshotAt;
        if (snapshotAtRaw != null && snapshotAtRaw.isNotEmpty) {
          try {
            snapshotAt = DateTime.parse(snapshotAtRaw);
          } catch (_) {}
        }
        DateTime? joinAt;
        if (joinAtRaw != null && joinAtRaw.isNotEmpty) {
          try {
            joinAt = DateTime.parse(joinAtRaw);
          } catch (_) {}
        }

        int? publicLevel;
        if (publicLevelRaw is int) {
          publicLevel = publicLevelRaw;
        } else if (publicLevelRaw is num) {
          publicLevel = publicLevelRaw.toInt();
        }

        result.add(
          StudyRoomMember(
            userId: uid,
            snapshotUrl: (snapshotUrl?.isNotEmpty ?? false) ? snapshotUrl : null,
            snapshotAt: snapshotAt,
            status: status,
            subjectName: subjectName,
            goalText: (goalText?.isNotEmpty ?? false) ? goalText : null,
            joinAt: joinAt,
            timerStartAt: null,
            timerDurationSecs: null,
            timerPaused: false,
            timerPauseRemainingSecs: null,
            publicLevel: publicLevel,
            publicTitleKo: (publicTitleKo?.isNotEmpty ?? false) ? publicTitleKo : null,
          ),
        );
      }
    }

    result.sort((a, b) {
      if (a.userId == selfId) return -1;
      if (b.userId == selfId) return 1;
      return 0;
    });

    _members = result;
    notifyListeners();
  }

  Future<void> _leavePresence() async {
    final ch = _presenceChannel;
    _presenceChannel = null;
    if (ch == null) return;
    try {
      await ch.untrack();
    } catch (_) {}
    try {
      await ch.unsubscribe();
    } catch (_) {}
  }

  Future<void> _ensureProfile(String userId) async {
    await supabase.from('profiles').upsert(
      {'id': userId, 'role': 'student'},
      onConflict: 'id',
    );
  }

  Future<void> _loadSelfRpgForPresence() async {
    final uid = _selfId;
    if (uid == null) return;
    try {
      final row = await supabase
          .from('profiles')
          .select('level, equipped_title_id')
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return;
      _selfPublicLevel = ((row['level'] ?? 1) as num).toInt();
      final tid = row['equipped_title_id'] as String?;
      if (tid != null) {
        final t = await supabase.from('titles').select('name_ko').eq('id', tid).maybeSingle();
        _selfPublicTitleKo = t?['name_ko'] as String?;
      } else {
        _selfPublicTitleKo = null;
      }
    } catch (e) {
      debugPrint('[StudyRoomController] _loadSelfRpgForPresence: $e');
      _selfPublicLevel = 1;
      _selfPublicTitleKo = null;
    }
  }
}
