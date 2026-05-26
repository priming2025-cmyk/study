import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../session/domain/attention_scoring.dart';
import '../../session/domain/attention_signals.dart';
import '../../session/domain/session_summary.dart';
import '../../session/infra/attention_camera_service.dart';
import '../../session/infra/session_media_lifecycle.dart';
import '../../session/infra/web_camera.dart';
import '../domain/study_room_join_code.dart';
import '../domain/study_room_models.dart';
import 'room_snapshot.dart';
import 'study_room_ambient_player.dart';

class StudyRoomCreated {
  final String roomId;
  final String joinCode;

  const StudyRoomCreated({required this.roomId, required this.joinCode});
}

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
  /// 화면·공유용 6자리 입장코드.
  String? joinCode;
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

  /// 웹 본인 카메라 위젯 재마운트용 (방 퇴장·재입장 시 정지 화면 방지).
  int webSelfCamEpoch = 0;

  /// 카메라 멈춤 시 수동 복구.
  Future<void> refreshSelfCamera() async {
    webSelfCamEpoch++;
    if (kIsWeb) {
      WebSharedCamera.instance.forceRelease();
      WebSharedCamera.instance.openFromUserGesture();
    } else {
      await AttentionCameraService.instance.forceStop();
    }
    notifyListeners();
  }

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

  AttentionScoringState? _focusState;
  Timer? _focusTimer;
  AttentionSignals _focusSignals = const AttentionSignals(
    facePresent: false,
    multiFace: false,
    appInForeground: true,
  );
  DateTime? _lastFocusSignalAt;
  int _engagedMinScore = 50;

  StudyRoomAmbientPlayer get ambient => _ambient;

  String get goalText => _selfGoalText;
  bool get isFocusTracking => _focusState != null;
  int get focusAverageScore => _focusState?.averageScore ?? 0;
  AttentionSignals get focusSignals => _focusSignals;

  StudyRoomMember? get hostMember {
    final oid = roomOwnerId;
    if (oid == null) return null;
    for (final m in _members) {
      if (m.userId == oid) return m;
    }
    return null;
  }

  String? reactionEmojiFor(String userId) => _reactions[userId]?.overlay.emoji;

  // ── 집중 추적 (공부 탭과 동일 AttentionScoring) ───────────────────────────

  void startFocusTracking(int engagedMinScore) {
    cancelFocusTracking();
    _engagedMinScore = engagedMinScore;
    _focusSignals = const AttentionSignals(
      facePresent: false,
      multiFace: false,
      appInForeground: true,
    );
    _lastFocusSignalAt = null;
    _focusState = AttentionScoringState.started(DateTime.now());
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onFocusTick());
    _onFocusTick();
    notifyListeners();
  }

  void feedFocusSignals(AttentionSignals signals) {
    _focusSignals = signals;
    _lastFocusSignalAt = DateTime.now();
  }

  void cancelFocusTracking() {
    _focusTimer?.cancel();
    _focusTimer = null;
    _focusState = null;
    _lastFocusSignalAt = null;
  }

  SessionSummary? endFocusTracking() {
    _focusTimer?.cancel();
    _focusTimer = null;
    final st = _focusState;
    _focusState = null;
    _lastFocusSignalAt = null;
    if (st == null) return null;
    final subject = _selfGoalText.trim().isEmpty ? '셋터디' : _selfGoalText.trim();
    return AttentionScoring.finalize(
      st,
      DateTime.now(),
      subject: subject,
      planItemId: null,
    );
  }

  void _onFocusTick() {
    final st = _focusState;
    if (st == null) return;
    final last = _lastFocusSignalAt;
    final ok = last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 3);
    final tickSignals = ok
        ? _focusSignals
        : const AttentionSignals(
            facePresent: false,
            multiFace: false,
            appInForeground: true,
          );
    _focusState = AttentionScoring.tick(
      state: st,
      now: DateTime.now(),
      signals: tickSignals,
      engagedMinScore: _engagedMinScore,
    );
    notifyListeners();
  }

  // ── 방 만들기 ──────────────────────────────────────────────────────────────

  Future<StudyRoomCreated> createRoom({required String name}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('로그인이 필요합니다.');

    await _ensureProfile(userId);

    Object? lastError;
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = generateStudyRoomJoinCode();
      try {
        final row = await supabase
            .from('study_rooms')
            .insert({
              'owner_id': userId,
              'name': name.trim().isEmpty ? '우리셋' : name.trim(),
              'max_peers': 8,
              'join_code': code,
            })
            .select('id, join_code')
            .single();
        final id = '${row['id']}';
        final savedCode =
            normalizeJoinCode('${row['join_code'] ?? code}');
        joinCode = savedCode;
        return StudyRoomCreated(roomId: id, joinCode: savedCode);
      } catch (e) {
        lastError = e;
        final msg = e.toString();
        if (msg.contains('unique') || msg.contains('duplicate')) {
          continue;
        }
        if (msg.contains('join_code') && attempt == 0) {
          final row = await supabase
              .from('study_rooms')
              .insert({
                'owner_id': userId,
                'name': name.trim().isEmpty ? '우리셋' : name.trim(),
                'max_peers': 8,
              })
              .select('id')
              .single();
          final id = '${row['id']}';
          final fallback = normalizeJoinCode(id.replaceAll('-', '').substring(0, 6));
          joinCode = fallback;
          return StudyRoomCreated(roomId: id, joinCode: fallback);
        }
        rethrow;
      }
    }
    throw StateError('입장코드 생성에 실패했어요: $lastError');
  }

  /// 입장코드 또는 UUID → 방 id. 없으면 null.
  Future<String?> resolveRoomIdFromEntry(String entry) async {
    final raw = entry.trim();
    if (raw.isEmpty) return null;

    if (raw.contains('-') && raw.length > 20) {
      final row = await supabase
          .from('study_rooms')
          .select('id')
          .eq('id', raw)
          .maybeSingle();
      return row?['id'] as String?;
    }

    final code = normalizeJoinCode(raw);
    try {
      final row = await supabase
          .from('study_rooms')
          .select('id')
          .eq('join_code', code)
          .maybeSingle();
      if (row != null) return row['id'] as String?;
    } catch (_) {
      // join_code 컬럼 미적용 DB
    }

    return null;
  }

  // ── 방 입장 ──────────────────────────────────────────────────────────────

  /// [roomIdOrCode]: 6자리 입장코드 또는 UUID. 성공 시 true.
  Future<bool> joinRoom({
    required String roomIdOrCode,
    String goalText = '',
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('로그인이 필요합니다.');

    joining = true;
    error = null;
    roomId = null;
    notifyListeners();

    try {
      await _ensureProfile(userId);

      final resolvedId = await resolveRoomIdFromEntry(roomIdOrCode);
      if (resolvedId == null) {
        error = '입장코드를 찾을 수 없어요. 코드를 다시 확인해 주세요.';
        return false;
      }

      final roomRow = await supabase
          .from('study_rooms')
          .select('owner_id, join_code')
          .eq('id', resolvedId)
          .maybeSingle();
      if (roomRow == null) {
        error = '입장코드를 찾을 수 없어요. 코드를 다시 확인해 주세요.';
        return false;
      }

      roomId = resolvedId;
      joinCode = roomRow['join_code'] != null
          ? normalizeJoinCode('${roomRow['join_code']}')
          : normalizeJoinCode(roomIdOrCode);
      _selfId = userId;
      _messages = [];
      _selfGoalText = goalText.trim();
      _selfJoinAtUtc = DateTime.now().toUtc();
      _selfStatus = 'focus';
      roomOwnerId = roomRow['owner_id'] as String?;

      await _loadSelfRpgForPresence();

      await supabase.from('study_room_members').upsert(
        {'room_id': resolvedId, 'user_id': userId, 'left_at': null},
        onConflict: 'room_id,user_id',
      );

      await _fetchMessages(resolvedId);
      await _joinMessageChannel(resolvedId);

      await _joinPresence(
        roomId: resolvedId,
        userId: userId,
        snapshotUrl: '',
      );
      unawaited(_finishJoinSnapshot(roomId: resolvedId, userId: userId));
      webSelfCamEpoch++;
      return true;
    } catch (e) {
      error = '방 입장 실패: $e';
      debugPrint('[StudyRoomController] joinRoom error: $e');
      roomId = null;
      return false;
    } finally {
      joining = false;
      notifyListeners();
    }
  }

  // ── 나가기 ────────────────────────────────────────────────────────────────

  /// 방 입장 후 스냅샷·주기 업로드를 백그라운드에서 처리합니다.
  Future<void> _finishJoinSnapshot({
    required String roomId,
    required String userId,
  }) async {
    try {
      if (!_snapshotInitialized) {
        await _snapshot.initialize();
        _snapshotInitialized = true;
      }
      await _uploadSnapshotWhenCameraReady(roomId: roomId, userId: userId);
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
      debugPrint('[StudyRoomController] snapshot: $e');
    }
  }

  /// 실시간 카메라([AttentionCameraService])가 켜질 때까지 재시도 후 첫 스냅샷을 올립니다.
  Future<void> _uploadSnapshotWhenCameraReady({
    required String roomId,
    required String userId,
  }) async {
    for (var i = 0; i < 30; i++) {
      if (this.roomId != roomId || _selfId != userId) return;
      final url = await _uploadSnapshot(roomId: roomId, userId: userId);
      if (url != null) {
        selfSnapshotUrl = url;
        await _trackSelfFull(snapshotUrl: url);
        notifyListeners();
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> leave() async {
    cancelFocusTracking();
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
    joinCode = null;
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
    try {
      await _snapshot.dispose();
    } catch (_) {}
    _snapshotInitialized = false;
    await releaseSharedCameraMedia();
    webSelfCamEpoch++;
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
