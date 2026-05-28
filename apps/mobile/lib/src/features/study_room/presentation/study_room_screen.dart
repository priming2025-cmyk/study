import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/providers/shell_branch_index_provider.dart';
import '../../../core/study/study_activity_gate.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/ui/app_snacks.dart';
import '../../social/infra/pending_friend_invite.dart';
import '../infra/pending_study_room_join.dart';
import '../../../core/widgets/sheet_header_bar.dart';
import '../../session/data/session_repository.dart';
import '../../session/domain/engaged_time_threshold.dart';
import '../../session/infra/web_shared_camera.dart';
import '../../session/presentation/widgets/session_end_result_sheet.dart';
import '../domain/study_room_reward_config.dart';
import '../infra/study_room_controller.dart';
import '../domain/study_room_join_code.dart';
import '../infra/study_room_recent_room.dart';
import 'widgets/settudy_social_view.dart';
import 'widgets/study_room_active_view.dart';
import '../../social/presentation/friend_dm_listener.dart';
import 'widgets/study_room_ambient_sheet.dart';
import 'widgets/study_room_create_sheet.dart';
import 'widgets/study_room_goal_sheet.dart';
import 'widgets/study_room_host_sheet.dart';
import 'widgets/study_room_invite_sheet.dart';
import 'widgets/study_room_celolog_sheet.dart';
import 'widgets/study_room_settings_sheet.dart';

class StudyRoomScreen extends ConsumerStatefulWidget {
  final bool quickJoin;
  const StudyRoomScreen({super.key, this.quickJoin = false});

  @override
  ConsumerState<StudyRoomScreen> createState() => _StudyRoomScreenState();
}

class _StudyRoomScreenState extends ConsumerState<StudyRoomScreen> {
  final _controller = StudyRoomController();
  final _roomIdCtrl = TextEditingController();
  late Future<List<RecentStudyRoom>> _recentFuture;

  late final ValueNotifier<int> _engagedMinScoreN =
      ValueNotifier(kDefaultEngagedMinScore);

  String? _lastCheerKey;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.onRecentRoomsActivityChanged = _refreshRecentRoomsList;
    _recentFuture = loadRecentStudyRooms();
    _loadEngagedScore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final params = GoRouterState.of(context).uri.queryParameters;
      final linkCode = params['join'];
      if (linkCode != null && linkCode.trim().isNotEmpty) {
        unawaited(PendingStudyRoomJoin.save(linkCode.trim()));
        unawaited(_joinFromInviteLink(linkCode.trim()));
      } else if (widget.quickJoin) {
        unawaited(_quickJoinRecent());
      }
      unawaited(_handleFriendInviteRef(params['friendRef']));
    });
  }

  Future<void> _loadEngagedScore() async {
    final v = await loadEngagedMinScore();
    if (!mounted) return;
    _engagedMinScoreN.value = v;
  }

  @override
  void dispose() {
    _controller.onRecentRoomsActivityChanged = null;
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _roomIdCtrl.dispose();
    _engagedMinScoreN.dispose();
    ref.read(studyRoomInRoomProvider.notifier).state = false;
    unawaited(StudyActivityGate.setInStudyRoom(false));
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
      ref.read(studyRoomInRoomProvider.notifier).state = _controller.roomId != null;
      unawaited(StudyActivityGate.setInStudyRoom(_controller.roomId != null));

      final selfId = _controller.selfId;
      if (selfId != null) {
        final overlay = _controller.reactionOverlayFor(selfId);
        if (overlay != null && overlay.emoji == '❤️') {
          final key = '${overlay.fromUserId ?? 'anon'}-${overlay.receivedAt.toIso8601String()}';
          if (_lastCheerKey != key) {
            _lastCheerKey = key;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('누군가가 나를 응원했어요'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(milliseconds: 1600),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _openDmChat(String peerUserId) async {
    final rid = _controller.roomId;
    if (rid != null) {
      await _controller.ensureRoomMatesFriends();
    }
    final name = _controller.displayNameFor(peerUserId)?.trim();
    final label = (name != null && name.isNotEmpty)
        ? name
        : (peerUserId.length > 8 ? peerUserId.substring(0, 8) : peerUserId);

    if (!mounted) return;
    openFriendDmChat(
      context,
      ref,
      peerId: peerUserId,
      peerDisplayName: label,
      peerAvatarUrl: _controller.avatarUrlFor(peerUserId),
    );
    _controller.markFriendDmThreadRead(peerUserId);
  }

  void _refreshRecentRoomsList() {
    if (!mounted) return;
    setState(() {
      _recentFuture = loadRecentStudyRooms();
    });
  }

  List<String> _memberDisplayNames() {
    return _controller.members
        .map((m) => m.displayName?.trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }

  Future<void> _persistRecentRoom() async {
    final id = _controller.roomId;
    if (id == null) return;
    final activityAt = _controller.messages.isNotEmpty
        ? _controller.messages
            .map((m) => m.createdAt)
            .reduce((a, b) => a.isAfter(b) ? a : b)
        : DateTime.now();
    await saveRecentStudyRoom(
      roomId: id,
      joinCode: _controller.joinCode ?? '',
      roomName: _controller.roomName ?? '',
      maxPeers: _controller.maxPeers ?? 8,
      goalText: _controller.goalText,
      participantNames: _memberDisplayNames(),
      lastActivityAt: activityAt,
    );
    if (mounted) {
      setState(() {
        _recentFuture = loadRecentStudyRooms();
      });
    }
  }

  Future<void> _openSensitivitySheet() async {
    final cur = _engagedMinScoreN.value;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StudyRoomSettingsSheet(
        isRoomHost: _controller.isRoomHost,
        initialRoomName: _controller.roomName ?? '',
        initialMaxPeers: _controller.maxPeers ?? 8,
        engagedMinScore: cur,
        onUpdateRoomSettings: (name, maxPeers) async {
          return _controller.updateRoomSettings(
            newName: name,
            newMaxPeers: maxPeers,
          );
        },
        onSelectSensitivity: (v) async {
          await saveEngagedMinScore(v);
          _engagedMinScoreN.value = v;
        },
      ),
    );
  }

  Future<void> _createRoom() async {
    final messenger = ScaffoldMessenger.of(context);
    final req = await showStudyRoomCreateSheet(context, initialMaxPeers: 4);
    if (!mounted || req == null) return;
    try {
      final created = await _controller.createRoom(
        name: req.name,
        maxPeers: req.maxPeers,
      );
      final ok = await _controller.joinRoom(
        roomIdOrCode: created.roomId,
        goalText: '',
      );
      if (ok && _controller.roomId != null) {
        _controller.startFocusTracking(_engagedMinScoreN.value);
        await _persistRecentRoom();
      } else if (_controller.error != null && mounted) {
        AppSnacks.showWithMessenger(messenger, _controller.error!);
      }
    } catch (e) {
      if (mounted) AppSnacks.showWithMessenger(messenger, '방 생성 실패: $e');
    }
  }

  Future<void> _joinWithEntry(String entry, {String? savedGoal}) async {
    if (_controller.joining || _controller.roomId != null) return;
    final code = normalizeJoinCode(entry);
    if (code.isEmpty) return;

    // `savedGoal`이 null이면(값 미제공)만 목표 시트를 보여줍니다.
    // 딥링크/최근 셋처럼 값이 이미 있는 경우에는 시트 없이 바로 입장합니다.
    final goal = savedGoal ?? (await showStudyRoomGoalSheet(context)) ?? '';
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await _controller.joinRoom(roomIdOrCode: code, goalText: goal);
    if (ok && _controller.roomId != null) {
      _controller.startFocusTracking(_engagedMinScoreN.value);
      await _persistRecentRoom();
    } else if (_controller.error != null && mounted) {
      AppSnacks.showWithMessenger(messenger, _controller.error!);
    }
  }

  Future<void> _joinRoom() =>
      _joinWithEntry(_roomIdCtrl.text.trim(), savedGoal: '');

  Future<void> _joinFromInviteLink(String code) async {
    await _joinWithEntry(code, savedGoal: '');
    if (!mounted) return;
    final uri = GoRouterState.of(context).uri;
    if (uri.queryParameters.containsKey('join')) {
      context.go('/room');
    }
  }

  Future<void> _handleFriendInviteRef(String? fromQuery) async {
    var refId = fromQuery?.trim();
    if (refId == null || refId.isEmpty) {
      refId = await PendingFriendInvite.consume();
    } else {
      await PendingFriendInvite.consume();
    }
    if (!mounted || refId == null || refId.isEmpty) return;

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      await PendingFriendInvite.save(refId);
      return;
    }
    if (uid == refId) return;

    final repo = ref.read(motivationRepositoryProvider);
    final result = await repo.sendFriendRequestSafe(toUserId: refId);
    if (!mounted) return;
    AppSnacks.show(context, result.message);
  }

  /// 최근 셋 카드 탭 → 저장된 목표로 바로 입장.
  Future<void> _joinRoomById(RecentStudyRoom room) async {
    final entry =
        room.joinCode.isNotEmpty ? room.joinCode : room.roomId;
    await _joinWithEntry(entry, savedGoal: room.goalText);
  }

  Future<void> _quickJoinRecent() async {
    if (_controller.joining || _controller.roomId != null) return;
    final recent = await loadRecentStudyRoom();
    if (!mounted) return;
    if (recent == null) return;
    final (rid, goalSaved) = recent;
    final goal = goalSaved.isNotEmpty
        ? goalSaved
        : (await showStudyRoomGoalSheet(context)) ?? '';
    if (!mounted) return;
    if (goal.isEmpty) return;
    final ok = await _controller.joinRoom(roomIdOrCode: rid, goalText: goal);
    if (ok && _controller.roomId != null) {
      _controller.startFocusTracking(_engagedMinScoreN.value);
      await _persistRecentRoom();
    } else if (_controller.error != null && mounted) {
      AppSnacks.showWithMessenger(
        ScaffoldMessenger.of(context),
        _controller.error!,
      );
    }
  }

  Future<void> _leaveAndSettle() async {
    if (_controller.roomId == null) return;
    final messenger = ScaffoldMessenger.of(context);

    final summary = _controller.endFocusTracking();
    await _persistRecentRoom();
    await _controller.leave();
    if (!mounted) return;

    if (summary == null) return;

    try {
      final repo = SessionRepository();
      final setudyBlocks =
          StudyRoomRewardConfig.blocksToAward(summary.focusedSeconds);
      final reward = await repo.applyRewardsForSummary(
        summary,
        setudyBonusBlocks: setudyBlocks,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: false,
        builder: (_) => SessionEndResultSheet(
          reward: reward,
          averageScore: summary.concentrationScore,
          focusedSeconds: summary.focusedSeconds,
        ),
      );
    } catch (e) {
      if (mounted) {
        AppSnacks.showWithMessenger(messenger, '저장 실패: $e');
      }
    }
  }

  void _showInviteSheetForRecent(RecentStudyRoom room) {
    final code = room.joinCode.isNotEmpty ? room.joinCode : room.displayCode;
    if (code.trim().isEmpty) return;
    StudyRoomInviteSheet.show(
      context,
      joinCode: code,
      goalText: room.goalText,
      shareOnly: true,
    );
  }

  /// 헤더 + 버튼 → 셋 만들기 / 입장 선택
  void _showCreateOrJoinMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeaderBar(
              title: '셋터디 시작',
              onClose: () => Navigator.pop(ctx),
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('셋 만들기'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (kIsWeb) WebSharedCamera.instance.openFromUserGesture();
                unawaited(_createRoom());
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.login_rounded),
              label: const Text('입장'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _showJoinCodeDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 입장 → 참여코드 입력 다이얼로그
  void _showJoinCodeDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('입장 코드 입력'),
          content: TextField(
            controller: _roomIdCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: '6자리 입장코드',
              border: OutlineInputBorder(),
            ),
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final id = _roomIdCtrl.text.trim();
              if (id.isEmpty) return;
              Navigator.pop(ctx);
              if (kIsWeb) WebSharedCamera.instance.openFromUserGesture();
              unawaited(_joinRoom());
            },
            child: const Text('입장'),
          ),
        ],
      ),
    );
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inRoom = _controller.roomId != null;
    final studyCameraSlotActive = ref.watch(shellBranchIndexProvider) == kShellBranchStudy;

    ref.listen<int>(studyRoomLeaveForTabSwitchProvider, (prev, next) {
      if (prev == null || next <= prev) return;
      if (_controller.roomId != null) {
        unawaited(_leaveAndSettle());
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: inRoom
          ? AppBar(
              title: const Text('셋터디'),
              actions: [
                IconButton(
                  tooltip: '다운로드',
                  icon: const Icon(Icons.download_rounded),
                  onPressed: () => showStudyRoomCelologSheet(
                    context,
                    roomId: _controller.roomId,
                  ),
                ),
                if (kIsWeb)
                  IconButton(
                    tooltip: '카메라 새로고침',
                    icon: const Icon(Icons.cameraswitch_rounded),
                    onPressed: () {
                      WebSharedCamera.instance.openFromUserGesture();
                      unawaited(_controller.refreshSelfCamera());
                    },
                  ),
                IconButton(
                  tooltip: '집중민감도',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: _openSensitivitySheet,
                ),
                IconButton(
                  tooltip: '배경음',
                  icon: const Icon(Icons.graphic_eq_rounded),
                  onPressed: () => showStudyRoomAmbientSheet(
                    context,
                    player: _controller.ambient,
                  ),
                ),
                if (_controller.isRoomHost)
                  IconButton(
                    tooltip: '방장 넘기기',
                    icon: const Icon(Icons.swap_horiz_rounded),
                    onPressed: () =>
                        showStudyRoomHostActionsSheet(context, _controller),
                  ),
              ],
            )
          : AppBar(
              title: const Text('셋터디'),
              titleTextStyle: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
              actions: [
                // + 버튼 → 셋 만들기 / 입장
                if (_controller.joining)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    tooltip: '셋 만들기 / 입장',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => _showCreateOrJoinMenu(context),
                  ),
                IconButton(
                  tooltip: '그룹 검색',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () {/* settudy_social_view의 검색 */},
                ),
              ],
            ),
      // FAB 완전 제거
      floatingActionButton: null,
      body: inRoom
          ? StudyRoomActiveView(
              controller: _controller,
              studyCameraSlotActive: studyCameraSlotActive,
              engagedMinListenable: _engagedMinScoreN,
              onOpenDmChat: _openDmChat,
            )
          : FutureBuilder<List<RecentStudyRoom>>(
              future: _recentFuture,
              builder: (context, snap) {
                final rooms = snap.data ?? const [];
                return SettudySocialView(
                  joining: _controller.joining,
                  recentRooms: rooms,
                  onCreateRoom: () {
                    if (kIsWeb) {
                      WebSharedCamera.instance.openFromUserGesture();
                    }
                    unawaited(_createRoom());
                  },
                  onJoinRoom: (room) {
                    if (kIsWeb) {
                      WebSharedCamera.instance.openFromUserGesture();
                    }
                    unawaited(_joinRoomById(room));
                  },
                  onInviteRoom: (room) => _showInviteSheetForRecent(room),
                  onJoinByCode: () => _showJoinCodeDialog(),
                );
              },
            ),
      bottomNavigationBar: inRoom
          ? SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => unawaited(_leaveAndSettle()),
                icon: const Icon(Icons.exit_to_app_rounded),
                label: const Text('셋 나가기'),
              ),
            )
          : null,
    );
  }
}
