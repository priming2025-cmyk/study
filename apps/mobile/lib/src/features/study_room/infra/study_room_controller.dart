import 'dart:async';

import 'package:flutter/foundation.dart'
    show ChangeNotifier, VoidCallback, debugPrint, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../session/domain/attention_scoring.dart';
import '../../session/domain/attention_signals.dart';
import '../../session/domain/session_summary.dart';
import '../../session/infra/attention_camera_service.dart';
import '../../session/infra/session_media_lifecycle.dart';
import '../../session/infra/web_camera.dart';
import '../../plan/data/plan_repository.dart';
import '../../plan/presentation/widgets/plan_time_utils.dart';
import '../domain/study_room_default_name.dart';
import '../domain/study_room_join_code.dart';
import '../../social/domain/friend_dm_models.dart';
import '../domain/study_room_models.dart';
import 'room_snapshot.dart';
import 'study_room_ambient_player.dart';
import 'study_room_recent_room.dart';

class StudyRoomCreated {
  final String roomId;
  final String joinCode;

  const StudyRoomCreated({required this.roomId, required this.joinCode});
}

const _snapshotBucket = 'study-snapshots';
const _captureInterval = Duration(minutes: 1);

DateTime _expiresAtEndOfLocalDay(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day + 1).toUtc();
}

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
  String? roomName;
  /// 방 인원수 제한(최대 참여 가능 인원).
  int? maxPeers;
  String? _selfId;
  String? get selfId => _selfId;
  String? selfSnapshotUrl;

  String? roomOwnerId;

  // ── 공개 모드: capture(1분 캡쳐) / rest(프로필 사진) ───────────────────────
  String _selfPublicViewerMode = 'capture';
  String get selfPublicViewerMode => _selfPublicViewerMode;
  bool get isPublicCaptureEnabled => _selfPublicViewerMode == 'capture';
  bool get isRoomHost =>
      roomOwnerId != null && _selfId != null && roomOwnerId == _selfId;

  List<StudyRoomMember> _members = const [];
  List<StudyRoomMember> get members => _members;

  /// 셀로그 그리드 빌더용 슬롯 목록.
  /// 자신이 맨 앞, 이후 peers를 입장 순서로 반환합니다.
  List<({String userId, String? displayName, String? statusText})>
      get celologMemberSlots {
    final result =
        <({String userId, String? displayName, String? statusText})>[];
    final self = _selfId;
    if (self != null) {
      result.add((
        userId: self,
        displayName: displayNameFor(self),
        statusText: _selfStatusText.trim().isEmpty ? null : _selfStatusText.trim(),
      ));
    }
    for (final m in _members) {
      if (m.userId == self) continue;
      result.add((
        userId: m.userId,
        displayName: m.displayName ?? displayNameFor(m.userId),
        statusText: m.statusText,
      ));
    }
    return result;
  }

  List<StudyRoomMessage> _messages = [];
  List<StudyRoomMessage> get messages => _messages;

  /// 방 전체 공개 채팅 캐시 — insert 콜백마다 갱신해 필터링 오버헤드를 제거합니다.
  List<StudyRoomMessage> _roomChatMessagesCache = [];
  List<StudyRoomMessage> get roomChatMessages => _roomChatMessagesCache;

  void _rebuildGroupChatCache() {
    _roomChatMessagesCache =
        _messages.where((m) => m.recipientUserId == null).toList();
  }

  /// insert 응답 + Realtime insert가 겹칠 때 중복 추가 방지.
  bool _appendMessageIfNew(StudyRoomMessage msg) {
    if (_messages.any((m) => m.id == msg.id)) return false;
    _messages.add(msg);
    if (msg.recipientUserId == null) {
      _roomChatMessagesCache.add(msg);
    }
    return true;
  }

  /// DM 스레드별 마지막 읽은 시각 (세션 내).
  final Map<String, DateTime> _dmReadAtByUser = {};
  // 친구 DM(=friend_messages) 미리보기/읽음 (셋터디 화면 표시용)
  final Map<String, String> _friendDmPreviewByUser = {};
  final Map<String, DateTime> _friendDmUnreadAtByUser = {};
  RealtimeChannel? _friendDmChannel;

  bool joining = false;
  String? error;

  /// 최근 셋 목록(활동시간·정렬) 갱신 시 UI에서 다시 로드할 때 사용.
  VoidCallback? onRecentRoomsActivityChanged;

  /// 웹 본인 카메라 위젯 재마운트용 (방 퇴장·재입장 시 정지 화면 방지).
  int webSelfCamEpoch = 0;

  /// 카메라 멈춤 시 수동 복구. 집중 시간은 유지하고, 복구 중 구간은 비집중으로만 집계합니다.
  Future<void> refreshSelfCamera() async {
    webSelfCamEpoch++;
    final st = _focusState;
    final wasPaused = st?.paused ?? false;
    if (st != null && !wasPaused) {
      _focusState = AttentionScoring.pause(st, DateTime.now());
    }
    _lastFocusSignalAt = null;

    if (kIsWeb) {
      WebSharedCamera.instance.forceRelease();
      WebSharedCamera.instance.openFromUserGesture();
    } else {
      await AttentionCameraService.instance.forceStop();
    }
    notifyListeners();

    final rid = roomId;
    final uid = _selfId;
    if (rid != null && uid != null && _selfPublicViewerMode == 'capture') {
      await _uploadSnapshotWhenCameraReady(roomId: rid, userId: uid);
    }

    if (_focusState != null && _focusState!.paused && !wasPaused) {
      _focusState = AttentionScoring.resume(_focusState!, DateTime.now());
    }
    notifyListeners();
  }

  RealtimeChannel? _presenceChannel;
  RealtimeChannel? _messageChannel;
  Timer? _snapshotTimer;
  /// 공개 모드 전환 시 진행 중인 캡쳐를 중단합니다.
  int _mediaCaptureGen = 0;
  /// 연속 캡쳐가 겹치지 않도록 직렬화.
  Future<void> _mediaCaptureChain = Future<void>.value();
  bool _snapshotInitialized = false;

  String _selfGoalText = '';
  String _selfStatusText = '';
  late DateTime _selfJoinAtUtc;
  DateTime? _roomEnterAtUtc;
  String _selfStatus = 'focus';
  String? _selfSubjectName;
  String? _selfDisplayName;
  String? _selfAvatarUrl;
  final Map<String, String> _displayNameByUserId = {};
  final Map<String, String> _avatarUrlByUserId = {};
  // 자리(슬롯) 고정용: 방에 들어온 뒤 최초 sync 기준으로 peer 순서를 고정한다.
  // 이후에는 새로 들어온 peer만 뒤에 추가하고, 기존 peer의 순서는 절대 바꾸지 않는다.
  final List<String> _fixedPeerOrder = [];

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
  String get statusText => _selfStatusText;
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

  StudyRoomReactionOverlay? reactionOverlayFor(String userId) =>
      _reactions[userId]?.overlay;

  String? reactionEmojiFor(String userId) => reactionOverlayFor(userId)?.emoji;

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

  Future<SessionSummary?> endFocusTracking() async {
    _focusTimer?.cancel();
    _focusTimer = null;
    final st = _focusState;
    _focusState = null;
    _lastFocusSignalAt = null;
    if (st == null) return null;
    final subject = _selfGoalText.trim().isEmpty ? '셋터디' : _selfGoalText.trim();
    String? planItemId;
    try {
      final plan = await PlanRepository().fetchTodayPlan();
      planItemId = activePlanItemForNow(plan, DateTime.now())?.id ??
          planItemMatchingSubject(plan, subject)?.id;
    } catch (_) {}
    return AttentionScoring.finalize(
      st,
      DateTime.now(),
      subject: subject,
      planItemId: planItemId,
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

  Future<StudyRoomCreated> createRoom({
    required String name,
    int maxPeers = 8,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('로그인이 필요합니다.');

    await _ensureProfile(userId);
    final cappedPeers = maxPeers.clamp(2, 8);
    this.maxPeers = cappedPeers;

    Object? lastError;
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = generateStudyRoomJoinCode();
      try {
        final row = await supabase
            .from('study_rooms')
            .insert({
              'owner_id': userId,
              'name': resolveStudyRoomName(name),
              'max_peers': cappedPeers,
              'join_code': code,
            })
            .select('id, join_code')
            .single();
        final id = '${row['id']}';
        final savedCode =
            normalizeJoinCode('${row['join_code'] ?? code}');
        joinCode = savedCode;
        roomName = resolveStudyRoomName(name);
        this.maxPeers = cappedPeers;
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
                'name': resolveStudyRoomName(name),
                'max_peers': cappedPeers,
              })
              .select('id')
              .single();
          final id = '${row['id']}';
          final fallback = normalizeJoinCode(id.replaceAll('-', '').substring(0, 6));
          joinCode = fallback;
          roomName = resolveStudyRoomName(name);
          this.maxPeers = cappedPeers;
          return StudyRoomCreated(roomId: id, joinCode: fallback);
        }
        rethrow;
      }
    }
    throw StateError('입장코드 생성에 실패했어요: $lastError');
  }

  // ── 방 설정(이름/인원수) 변경 ───────────────────────────────────────────

  /// 방장만 가능. [study_rooms]의 `name`, `max_peers`를 변경합니다.
  Future<bool> updateRoomSettings({
    required String newName,
    required int newMaxPeers,
  }) async {
    final rid = roomId;
    final userId = supabase.auth.currentUser?.id;
    if (rid == null) return false;
    if (userId == null) throw StateError('로그인이 필요합니다.');
    if (!isRoomHost) return false;

    final cappedPeers = newMaxPeers.clamp(2, 8);
    final name = resolveStudyRoomName(newName);

    try {
      await supabase
          .from('study_rooms')
          .update({
            'name': name,
            'max_peers': cappedPeers,
          })
          .eq('id', rid);

      roomName = name;
      maxPeers = cappedPeers;
      notifyListeners();
      return true;
    } catch (e) {
      error = '설정 변경 실패: $e';
      notifyListeners();
      return false;
    }
  }

  /// RLS 밖 SECURITY DEFINER RPC — 비멤버도 입장코드로 방 메타 조회.
  Future<Map<String, dynamic>?> _lookupRoomForJoin(String entry) async {
    final raw = entry.trim();
    if (raw.isEmpty) return null;
    try {
      final result = await supabase.rpc(
        'lookup_study_room_for_join',
        params: {'p_entry': raw},
      );
      if (result == null) return null;
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
      return null;
    } catch (e) {
      debugPrint('[StudyRoomController] lookup_study_room_for_join: $e');
      return null;
    }
  }

  /// 입장코드 또는 UUID → 방 id. 없으면 null.
  Future<String?> resolveRoomIdFromEntry(String entry) async {
    final row = await _lookupRoomForJoin(entry);
    return row?['id'] as String?;
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

      final roomRow = await _lookupRoomForJoin(roomIdOrCode);
      if (roomRow == null) {
        error = '입장코드를 찾을 수 없어요. 코드를 다시 확인해 주세요.';
        return false;
      }

      final resolvedId = roomRow['id'] as String?;
      if (resolvedId == null || resolvedId.isEmpty) {
        error = '입장코드를 찾을 수 없어요. 코드를 다시 확인해 주세요.';
        return false;
      }

      roomId = resolvedId;
      joinCode = roomRow['join_code'] != null
          ? normalizeJoinCode('${roomRow['join_code']}')
          : normalizeJoinCode(roomIdOrCode);
      roomName = '${roomRow['name'] ?? ''}'.trim();
      maxPeers = (roomRow['max_peers'] as num?)?.toInt().clamp(2, 8) ?? 8;
      _selfId = userId;
      _messages = [];
      _roomChatMessagesCache = [];
      _dmReadAtByUser.clear();
      _friendDmPreviewByUser.clear();
      _friendDmUnreadAtByUser.clear();
      _fixedPeerOrder.clear();
      _selfGoalText = goalText.trim();
      if (_selfStatusText.trim().isEmpty) {
        _selfStatusText = _selfGoalText;
      }
      _selfJoinAtUtc = DateTime.now().toUtc();
      _roomEnterAtUtc = _selfJoinAtUtc;
      _selfStatus = 'focus';
      roomOwnerId = roomRow['owner_id'] as String?;

      await _loadSelfRpgForPresence();

      await supabase.from('study_room_members').upsert(
        {'room_id': resolvedId, 'user_id': userId, 'left_at': null},
        onConflict: 'room_id,user_id',
      );

      // 요구사항: 방에 새로 들어오면 과거 채팅은 보이지 않게(새 상태로 시작)
      await _fetchMessages(resolvedId, after: _roomEnterAtUtc);
      await _joinMessageChannel(resolvedId);

      await _joinPresence(
        roomId: resolvedId,
        userId: userId,
        snapshotUrl: '',
      );
      await _joinFriendDmChannel();
      unawaited(_refreshFriendDmPreviews());
      unawaited(_finishJoinSnapshot(roomId: resolvedId, userId: userId));
      unawaited(ensureRoomMatesFriends());
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
      if (_selfPublicViewerMode == 'rest') {
        await _applyRestProfilePresence();
      } else {
        await _uploadSnapshotWhenCameraReady(roomId: roomId, userId: userId);
        _restartSnapshotTimer();
      }
    } catch (e) {
      debugPrint('[StudyRoomController] snapshot: $e');
    }
  }

  /// 실시간 카메라([AttentionCameraService])가 켜질 때까지 재시도 후 첫 스냅샷을 올립니다.
  Future<void> _uploadSnapshotWhenCameraReady({
    required String roomId,
    required String userId,
  }) async {
    if (_selfPublicViewerMode != 'capture') return;
    final waitGen = _mediaCaptureGen;
    for (var i = 0; i < 30; i++) {
      if (this.roomId != roomId || _selfId != userId) return;
      if (_selfPublicViewerMode != 'capture' || waitGen != _mediaCaptureGen) {
        return;
      }
      if (kIsWeb) {
        if (!WebSharedCamera.instance.isStreamReady) {
          WebSharedCamera.instance.openFromUserGesture();
          await WebSharedCamera.instance.acquire();
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
      } else if (!AttentionCameraService.instance.hasActiveCamera) {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      final url = await _runMediaExclusive(
        () => _uploadSnapshot(roomId: roomId, userId: userId),
      );
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
    _roomChatMessagesCache = [];
    _dmReadAtByUser.clear();
    _fixedPeerOrder.clear();
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
    await _leaveFriendDmChannel();
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
    final text = content.trim();
    if (rid == null || uid == null || text.isEmpty) return;

    try {
      final row = await supabase
          .from('study_room_messages')
          .insert({
            'room_id': rid,
            'user_id': uid,
            'content': text,
          })
          .select()
          .single();
      final msg = StudyRoomMessage.fromJson(row);
      if (_appendMessageIfNew(msg)) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[StudyRoomController] sendMessage error: $e');
    }
  }

  Future<({bool ok, String? error})> sendDirectMessage({
    required String recipientUserId,
    required String content,
  }) async {
    final rid = roomId;
    final uid = _selfId;
    final text = content.trim();
    if (rid == null || uid == null) {
      return (ok: false, error: '셋터디 방에 입장한 뒤 메시지를 보낼 수 있어요');
    }
    if (text.isEmpty) return (ok: false, error: '메시지를 입력해 주세요');
    if (recipientUserId == uid) {
      return (ok: false, error: '본인에게는 보낼 수 없어요');
    }

    try {
      await supabase.from('study_room_members').upsert(
        {'room_id': rid, 'user_id': uid, 'left_at': null},
        onConflict: 'room_id,user_id',
      );
      final row = await supabase
          .from('study_room_messages')
          .insert({
            'room_id': rid,
            'user_id': uid,
            'recipient_user_id': recipientUserId,
            'content': text,
          })
          .select()
          .single();
      final msg = StudyRoomMessage.fromJson(row);
      if (_appendMessageIfNew(msg)) {
        notifyListeners();
      }
      return (ok: true, error: null);
    } catch (e) {
      debugPrint('[StudyRoomController] sendDirectMessage error: $e');
      return (
        ok: false,
        error: '메시지를 보내지 못했어요. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  /// 나와 [otherUserId] 사이 1:1 메시지 (시간순).
  List<StudyRoomMessage> messagesWithUser(String otherUserId) {
    final self = _selfId;
    if (self == null) return const [];

    return _messages
        .where((m) {
          if (m.recipientUserId == null) return false;
          return (m.userId == self && m.recipientUserId == otherUserId) ||
              (m.userId == otherUserId && m.recipientUserId == self);
        })
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  StudyRoomMessage? latestUnreadIncoming() {
    final self = _selfId;
    if (self == null) return null;

    StudyRoomMessage? best;
    for (final m in _messages) {
      if (m.recipientUserId != self || m.userId == self) continue;
      final readAt = _dmReadAtByUser[m.userId];
      if (readAt != null && !m.createdAt.isAfter(readAt)) continue;
      if (best == null || m.createdAt.isAfter(best.createdAt)) {
        best = m;
      }
    }
    return best;
  }

  bool hasUnreadFromUser(String otherUserId) {
    final self = _selfId;
    if (self == null) return false;
    final readAt = _dmReadAtByUser[otherUserId];
    for (final m in _messages) {
      if (m.userId != otherUserId || m.recipientUserId != self) continue;
      if (readAt == null || m.createdAt.isAfter(readAt)) return true;
    }
    return false;
  }

  StudyRoomMessage? latestMessageWithUser(String otherUserId) {
    final thread = messagesWithUser(otherUserId);
    return thread.isEmpty ? null : thread.last;
  }

  void markDmThreadRead(String otherUserId) {
    _dmReadAtByUser[otherUserId] = DateTime.now();
    notifyListeners();
  }

  void _applyFriendDmPreview({
    required String peerUserId,
    required String content,
    bool markUnread = false,
  }) {
    final text = content.trim();
    if (text.isEmpty) return;
    if (!_members.any((m) => m.userId == peerUserId)) return;
    _friendDmPreviewByUser[peerUserId] = text;
    if (markUnread) {
      _friendDmUnreadAtByUser[peerUserId] = DateTime.now();
    }
    notifyListeners();
  }

  /// 방 멤버와의 친구 DM 최신 글을 카드 미리보기에 반영합니다.
  Future<void> refreshFriendDmPreviews() => _refreshFriendDmPreviews();

  Future<void> _refreshFriendDmPreviews() async {
    if (_selfId == null || roomId == null) return;
    try {
      final rows = await supabase.rpc('list_friend_dm_threads');
      if (rows is! List) return;
      var changed = false;
      for (final row in rows) {
        final thread =
            FriendDmThread.fromJson(row as Map<String, dynamic>);
        if (!_members.any((m) => m.userId == thread.peerId)) continue;
        final content = thread.lastContent?.trim() ?? '';
        if (content.isEmpty) continue;
        _friendDmPreviewByUser[thread.peerId] = content;
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (e) {
      debugPrint('[StudyRoomController] refreshFriendDmPreviews: $e');
    }
  }

  Future<void> _joinFriendDmChannel() async {
    final uid = _selfId;
    if (uid == null) return;
    await _leaveFriendDmChannel();

    void onFriendDmInsert(Map<String, dynamic> row) {
      final senderId = row['sender_id'] as String?;
      final recipientId = row['recipient_id'] as String?;
      final content = (row['content'] as String?)?.trim() ?? '';
      if (senderId == null || recipientId == null || content.isEmpty) {
        return;
      }
      if (senderId == uid) {
        _applyFriendDmPreview(peerUserId: recipientId, content: content);
      } else if (recipientId == uid) {
        _applyFriendDmPreview(
          peerUserId: senderId,
          content: content,
          markUnread: true,
        );
      }
    }

    _friendDmChannel = supabase
        .channel('friend_messages_inbox:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friend_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: uid,
          ),
          callback: (payload) => onFriendDmInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friend_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: uid,
          ),
          callback: (payload) => onFriendDmInsert(payload.newRecord),
        )
        .subscribe();
  }

  Future<void> _leaveFriendDmChannel() async {
    final ch = _friendDmChannel;
    _friendDmChannel = null;
    if (ch != null) {
      try {
        await ch.unsubscribe();
      } catch (_) {}
    }
  }

  String? friendDmPreviewWithUser(String otherUserId) =>
      _friendDmPreviewByUser[otherUserId];

  bool hasFriendDmUnreadFromUser(String otherUserId) =>
      _friendDmUnreadAtByUser.containsKey(otherUserId);

  void markFriendDmThreadRead(String otherUserId) {
    _friendDmUnreadAtByUser.remove(otherUserId);
    notifyListeners();
  }

  Future<void> setSelfPublicCaptureEnabled(bool enabled) async {
    await setSelfPublicViewerMode(enabled ? 'capture' : 'rest');
  }

  Future<void> setSelfPublicViewerMode(String mode) async {
    final m = mode.trim();
    if (m != 'capture' && m != 'rest') return;
    if (_selfPublicViewerMode == m) return;
    _mediaCaptureGen++;
    _selfPublicViewerMode = m;
    if (m == 'rest') {
      await _applyRestProfilePresence();
    } else {
      _restartSnapshotTimer();
      final rid = roomId;
      final uid = _selfId;
      if (rid != null && uid != null) {
        unawaited(_uploadSnapshotWhenCameraReady(roomId: rid, userId: uid));
      }
    }
    await _trackSelfFull(snapshotUrl: selfSnapshotUrl);
    notifyListeners();
  }

  Future<T> _runMediaExclusive<T>(Future<T> Function() action) {
    final next = _mediaCaptureChain.then((_) => action());
    _mediaCaptureChain = next.then((_) {}, onError: (_) {});
    return next;
  }

  bool get _hasRoomPeers =>
      _members.any((m) => m.userId != _selfId);

  Future<void> _applyRestProfilePresence() async {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    final avatar = (_selfAvatarUrl ?? '').trim();
    selfSnapshotUrl = avatar.isNotEmpty ? avatar : null;
    await _trackSelfFull(snapshotUrl: selfSnapshotUrl);
    notifyListeners();
  }

  String? avatarUrlFor(String userId) {
    if (userId == _selfId) return _selfAvatarUrl;
    return _avatarUrlByUserId[userId];
  }

  Future<void> ensureRoomMatesFriends() async {
    final rid = roomId;
    if (rid == null) return;
    try {
      await supabase.rpc(
        'ensure_study_room_mates_friends',
        params: {'p_room_id': rid},
      );
    } catch (e) {
      debugPrint('[StudyRoomController] ensureRoomMatesFriends: $e');
    }
  }

  String? displayNameFor(String userId) {
    for (final m in _members) {
      if (m.userId == userId && (m.displayName?.trim().isNotEmpty ?? false)) {
        return m.displayName!.trim();
      }
    }
    return _displayNameByUserId[userId];
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

  Future<void> _trackSelfFull({
    String? snapshotUrl,
  }) async {
    final ch = _presenceChannel;
    final uid = _selfId;
    if (ch == null || uid == null) return;

    final snap = snapshotUrl ?? selfSnapshotUrl ?? '';
    final payload = <String, dynamic>{
      'user_id': uid,
      'display_name': _selfDisplayName ?? '',
      'avatar_url': _selfAvatarUrl ?? '',
      'snapshot_url': snap,
      'snapshot_at': DateTime.now().toUtc().toIso8601String(),
      'status': _selfStatus,
      'focus_score': focusAverageScore,
      'public_viewer_mode': _selfPublicViewerMode,
      'latest_clip_url': '',
      'latest_clip_at': '',
      'subject_name': _selfSubjectName,
      'goal_text': _selfGoalText,
      'status_text': _selfStatusText,
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
    final fromUserId = payload['from_user_id'] as String?;
    if (target == null || emoji == null) return;

    _reactions[target]?.timer.cancel();
    _reactions.remove(target);

    final overlay = StudyRoomReactionOverlay(
      emoji: emoji,
      fromUserId: fromUserId,
      receivedAt: DateTime.now(),
    );
    final timer = Timer(const Duration(milliseconds: 2400), () {
      _reactions.remove(target);
      notifyListeners();
    });
    _reactions[target] = _ReactionEntry(overlay: overlay, timer: timer);
    notifyListeners();
  }

  Future<void> _fetchMessages(String roomId, {DateTime? after}) async {
    try {
      // postgrest 버전에 따라 gte() 체인이 지원되지 않는 경우가 있어 filter로 통일합니다.
      final base = supabase
          .from('study_room_messages')
          .select()
          .eq('room_id', roomId);
      final q = after == null
          ? base
          : base.filter('created_at', 'gte', after.toUtc().toIso8601String());
      final rows = await q
          .order('created_at', ascending: true)
          .limit(100);
      _messages = rows.map((r) => StudyRoomMessage.fromJson(r)).toList();
      _rebuildGroupChatCache();
      final last = _messages.isNotEmpty ? _messages.last.createdAt : null;
      if (last != null) unawaited(_touchRecentActivity(last));
      notifyListeners();
    } catch (e) {
      debugPrint('[StudyRoomController] fetch messages error: $e');
    }
  }

  Future<void> _touchRecentActivity(DateTime at) async {
    final rid = roomId;
    if (rid == null) return;
    final ok = await touchRecentStudyRoomActivity(roomId: rid, activityAt: at);
    if (ok) onRecentRoomsActivityChanged?.call();
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
            if (!_appendMessageIfNew(newMsg)) return;
            unawaited(_touchRecentActivity(newMsg.createdAt));
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

  void _restartSnapshotTimer() {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    final rid = roomId;
    final uid = _selfId;
    if (rid == null || uid == null) return;

    if (_selfPublicViewerMode == 'rest') {
      unawaited(_applyRestProfilePresence());
      return;
    }

    Future<void> tick() async {
      if (roomId != rid || _selfId != uid) return;
      if (_selfPublicViewerMode != 'capture') return;
      await _runMediaExclusive(() async {
        if (roomId != rid || _selfId != uid) return;
        if (_selfPublicViewerMode != 'capture') return;
        final url = await _uploadSnapshot(roomId: rid, userId: uid);
        if (url != null) {
          selfSnapshotUrl = url;
          await _trackSelfFull(snapshotUrl: url);
          notifyListeners();
        }
      });
    }

    unawaited(tick());
    _snapshotTimer = Timer.periodic(_captureInterval, (_) => unawaited(tick()));
  }

  Future<void> setMyStatusText(String text) async {
    final t = text.trim();
    _selfStatusText = t;
    await _trackSelfFull();
    notifyListeners();
  }

  Future<String?> _uploadSnapshot({
    required String roomId,
    required String userId,
    String suffix = '',
  }) async {
    if (_selfPublicViewerMode != 'capture') return null;
    try {
      final bytes = await _snapshot.capture();
      if (bytes == null) return null;

      // 캡쳐 모드에서는 1분 사진 히스토리를 쌓아 셋로그(타임랩스)로 만들 수 있게 합니다.
      final nowUtc = DateTime.now().toUtc();
      final ts = nowUtc.millisecondsSinceEpoch;
      final saveHistory =
          _selfPublicViewerMode == 'capture' &&
          roomId == this.roomId &&
          _hasRoomPeers;

      final path = saveHistory
          ? 'snaps/$roomId/$userId/$ts.jpg'
          : (suffix.isEmpty ? '$roomId/$userId.jpg' : '$roomId/${userId}_$suffix.jpg');
      await supabase.storage.from(_snapshotBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/jpeg',
              upsert: !saveHistory,
            ),
          );

      final base = supabase.storage.from(_snapshotBucket).getPublicUrl(path);
      final url = '$base?t=$ts';

      if (saveHistory) {
        try {
          await supabase.from('study_room_photo_snaps').insert({
            'room_id': roomId,
            'user_id': userId,
            'storage_path': path,
            'public_url': url,
            'recorded_at': nowUtc.toIso8601String(),
            'expires_at': _expiresAtEndOfLocalDay(nowUtc).toIso8601String(),
            'size_bytes': bytes.length,
            if (_selfStatusText.trim().isNotEmpty) 'status_text': _selfStatusText.trim(),
            // 집중도(0..100): StudyRoomController 내부 AttentionScoring 평균값
            if (focusAverageScore > 0) 'focus_score': focusAverageScore,
          });
        } catch (e) {
          debugPrint('[StudyRoomController] photo_snaps insert error: $e');
        }
      }

      return url;
    } catch (e) {
      debugPrint('[StudyRoomController] snapshot upload error: $e');
      return null;
    } finally {
      if (!kIsWeb) {
        unawaited(AttentionCameraService.instance.ensurePreviewStreamRunning());
      }
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
        final focusScore = (p['focus_score'] as num?)?.toInt();
        final publicViewerMode = p['public_viewer_mode'] as String?;
        final latestClipUrlRaw = p['latest_clip_url'] as String?;
        final latestClipAtRaw = p['latest_clip_at'] as String?;
        final subjectName = p['subject_name'] as String?;
        final goalText = p['goal_text'] as String?;
        final statusText = p['status_text'] as String?;
        final joinAtRaw = p['join_at'] as String?;
        final publicLevelRaw = p['public_level'];
        final publicTitleKo = p['public_title_ko'] as String?;

        DateTime? snapshotAt;
        if (snapshotAtRaw != null && snapshotAtRaw.isNotEmpty) {
          try {
            snapshotAt = DateTime.parse(snapshotAtRaw);
          } catch (_) {}
        }
        DateTime? latestClipAt;
        if (latestClipAtRaw != null && latestClipAtRaw.isNotEmpty) {
          try {
            latestClipAt = DateTime.parse(latestClipAtRaw);
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

        final rawName = p['display_name'] as String?;
        final displayName = (rawName != null && rawName.trim().isNotEmpty)
            ? rawName.trim()
            : _displayNameByUserId[uid];

        result.add(
          StudyRoomMember(
            userId: uid,
            displayName: displayName,
            snapshotUrl: (snapshotUrl?.isNotEmpty ?? false) ? snapshotUrl : null,
            snapshotAt: snapshotAt,
            status: status,
            focusScore: focusScore,
            publicViewerMode: publicViewerMode,
            latestClipUrl: (latestClipUrlRaw?.isNotEmpty ?? false)
                ? latestClipUrlRaw
                : null,
            latestClipAt: latestClipAt,
            subjectName: subjectName,
            goalText: (goalText?.isNotEmpty ?? false) ? goalText : null,
            statusText: (statusText?.isNotEmpty ?? false) ? statusText : null,
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

    // 1) self는 항상 첫 번째
    // 2) peers는 최초 sync에서 결정된 순서로 “고정”
    final self = result.where((m) => m.userId == selfId).toList();
    final peersNow = result.where((m) => m.userId != selfId).toList();

    // 최초 고정 순서가 없으면: joinAt 오름차순(없으면 userId)으로 고정 순서를 만든다.
    if (_fixedPeerOrder.isEmpty) {
      peersNow.sort((a, b) {
        final aj = a.joinAt;
        final bj = b.joinAt;
        if (aj == null && bj == null) return a.userId.compareTo(b.userId);
        if (aj == null) return 1;
        if (bj == null) return -1;
        final t = aj.compareTo(bj);
        if (t != 0) return t;
        return a.userId.compareTo(b.userId);
      });
      _fixedPeerOrder.addAll(peersNow.map((m) => m.userId));
    } else {
      // 이미 고정된 순서가 있으면:
      // - 나간 사람 제거
      final nowIds = peersNow.map((m) => m.userId).toSet();
      _fixedPeerOrder.removeWhere((id) => !nowIds.contains(id));
      // - 새로 들어온 사람은 뒤에 추가 (빈 슬롯 채우기 개념)
      for (final m in peersNow) {
        if (!_fixedPeerOrder.contains(m.userId)) _fixedPeerOrder.add(m.userId);
      }
    }

    // 고정 순서대로 peers를 재조립
    final byId = <String, StudyRoomMember>{
      for (final m in peersNow) m.userId: m,
    };
    final orderedPeers = <StudyRoomMember>[
      for (final id in _fixedPeerOrder)
        if (byId[id] != null) byId[id]!,
    ];

    final merged = <StudyRoomMember>[
      if (self.isNotEmpty) self.first,
      ...orderedPeers,
    ];

    _members = merged;
    notifyListeners();
    unawaited(_hydrateMemberDisplayNames(merged.map((m) => m.userId)));
  }

  Future<void> _hydrateMemberDisplayNames(Iterable<String> userIds) async {
    final missing = userIds
        .where(
          (id) =>
              !_displayNameByUserId.containsKey(id) ||
              !_avatarUrlByUserId.containsKey(id),
        )
        .toSet()
        .toList();
    if (missing.isEmpty) return;
    try {
      final rows = await supabase
          .from('profiles')
          .select('id, display_name, avatar_url')
          .inFilter('id', missing);
      for (final row in rows) {
        final id = row['id'] as String?;
        final name = (row['display_name'] as String?)?.trim();
        if (id != null && name != null && name.isNotEmpty) {
          _displayNameByUserId[id] = name;
        }
        final av = (row['avatar_url'] as String?)?.trim();
        if (id != null && av != null && av.isNotEmpty) {
          _avatarUrlByUserId[id] = av;
        }
      }
      if (_members.isEmpty) return;
      _members = _members
          .map(
            (m) => StudyRoomMember(
              userId: m.userId,
              displayName: m.displayName ?? _displayNameByUserId[m.userId],
              snapshotUrl: m.publicViewerMode == 'rest'
                  ? (_avatarUrlByUserId[m.userId] ?? m.snapshotUrl)
                  : m.snapshotUrl,
              snapshotAt: m.snapshotAt,
              status: m.status,
              focusScore: m.focusScore,
              publicViewerMode: m.publicViewerMode,
              latestClipUrl: m.latestClipUrl,
              latestClipAt: m.latestClipAt,
              subjectName: m.subjectName,
              goalText: m.goalText,
              statusText: m.statusText,
              joinAt: m.joinAt,
              timerStartAt: m.timerStartAt,
              timerDurationSecs: m.timerDurationSecs,
              timerPaused: m.timerPaused,
              timerPauseRemainingSecs: m.timerPauseRemainingSecs,
              publicLevel: m.publicLevel,
              publicTitleKo: m.publicTitleKo,
            ),
          )
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('[StudyRoomController] hydrate names: $e');
    }
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
          .select('level, equipped_title_id, display_name, avatar_url')
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return;
      final dn = (row['display_name'] as String?)?.trim();
      if (dn != null && dn.isNotEmpty) {
        _selfDisplayName = dn;
        _displayNameByUserId[uid] = dn;
      }
      final av = (row['avatar_url'] as String?)?.trim();
      if (av != null && av.isNotEmpty) {
        _selfAvatarUrl = av;
        _avatarUrlByUserId[uid] = av;
      }
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
