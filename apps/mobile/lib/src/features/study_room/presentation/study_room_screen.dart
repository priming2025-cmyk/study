import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/shell_branch_index_provider.dart';
import '../../../core/ui/app_snacks.dart';
import '../../session/data/session_repository.dart';
import '../../session/domain/engaged_time_threshold.dart';
import '../../session/infra/web_shared_camera.dart';
import '../../session/presentation/widgets/session_settings_sheet.dart';
import '../../session/presentation/widgets/session_end_result_sheet.dart';
import '../domain/study_room_reward_config.dart';
import '../infra/study_room_controller.dart';
import '../infra/study_room_recent_room.dart';
import 'widgets/settudy_social_view.dart';
import 'widgets/study_room_active_view.dart';
import 'widgets/study_room_ambient_sheet.dart';
import 'widgets/study_room_goal_sheet.dart';
import 'widgets/study_room_host_sheet.dart';
import 'widgets/study_room_invite_sheet.dart';

class StudyRoomScreen extends ConsumerStatefulWidget {
  final bool quickJoin;
  const StudyRoomScreen({super.key, this.quickJoin = false});

  @override
  ConsumerState<StudyRoomScreen> createState() => _StudyRoomScreenState();
}

class _StudyRoomScreenState extends ConsumerState<StudyRoomScreen> {
  final _controller = StudyRoomController();
  final _roomNameCtrl = TextEditingController(text: '우리셋');
  final _roomIdCtrl = TextEditingController();
  late Future<List<RecentStudyRoom>> _recentFuture;

  late final ValueNotifier<int> _engagedMinScoreN =
      ValueNotifier(kDefaultEngagedMinScore);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _recentFuture = loadRecentStudyRooms();
    _loadEngagedScore();
    if (widget.quickJoin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _quickJoinRecent();
      });
    }
  }

  Future<void> _loadEngagedScore() async {
    final v = await loadEngagedMinScore();
    if (!mounted) return;
    _engagedMinScoreN.value = v;
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _roomNameCtrl.dispose();
    _roomIdCtrl.dispose();
    _engagedMinScoreN.dispose();
    ref.read(studyRoomInRoomProvider.notifier).state = false;
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
      ref.read(studyRoomInRoomProvider.notifier).state = _controller.roomId != null;
    }
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
    await saveRecentStudyRoom(
      roomId: id,
      goalText: _controller.goalText,
      participantNames: _memberDisplayNames(),
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
      showDragHandle: true,
      builder: (ctx) => SessionSettingsSheet(
        engagedMinScore: cur,
        onSelectSensitivity: (v) async {
          await saveEngagedMinScore(v);
          _engagedMinScoreN.value = v;
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _createRoom() async {
    final messenger = ScaffoldMessenger.of(context);
    final goal = await showStudyRoomGoalSheet(context);
    if (!mounted || goal == null) return;
    try {
      final roomId = await _controller.createRoom(name: _roomNameCtrl.text);
      await _controller.joinRoom(roomId: roomId, goalText: goal);
      if (_controller.roomId != null) {
        _controller.startFocusTracking(_engagedMinScoreN.value);
        await _persistRecentRoom();
      }
      if (_controller.error != null && mounted) {
        AppSnacks.showWithMessenger(messenger, _controller.error!);
      }
    } catch (e) {
      if (mounted) AppSnacks.showWithMessenger(messenger, '방 생성 실패: $e');
    }
  }

  Future<void> _joinRoom() async {
    final id = _roomIdCtrl.text.trim();
    if (id.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final goal = await showStudyRoomGoalSheet(context);
    if (!mounted || goal == null) return;
    await _controller.joinRoom(roomId: id, goalText: goal);
    if (_controller.roomId != null) {
      _controller.startFocusTracking(_engagedMinScoreN.value);
      await _persistRecentRoom();
    }
    if (_controller.error != null && mounted) {
      AppSnacks.showWithMessenger(messenger, _controller.error!);
    }
  }

  /// 최근 셋 카드 탭 → 저장된 목표로 바로 입장.
  Future<void> _joinRoomById(String roomId, String savedGoal) async {
    if (_controller.joining || _controller.roomId != null) return;
    final goal = savedGoal.isNotEmpty
        ? savedGoal
        : (await showStudyRoomGoalSheet(context)) ?? '';
    if (!mounted || goal.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    await _controller.joinRoom(roomId: roomId, goalText: goal);
    if (_controller.roomId != null) {
      _controller.startFocusTracking(_engagedMinScoreN.value);
      await _persistRecentRoom();
    }
    if (_controller.error != null && mounted) {
      AppSnacks.showWithMessenger(messenger, _controller.error!);
    }
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
    await _controller.joinRoom(roomId: rid, goalText: goal);
    if (_controller.roomId != null) {
      _controller.startFocusTracking(_engagedMinScoreN.value);
      await _persistRecentRoom();
    }
    if (_controller.error != null && mounted) {
      AppSnacks.showWithMessenger(
        ScaffoldMessenger.of(context),
        _controller.error!,
      );
    }
  }

  Future<void> _showJoinByIdDialog(BuildContext context) async {
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('ID로 참여'),
          content: TextField(
            controller: _roomIdCtrl,
            decoration: const InputDecoration(hintText: '셋 ID'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _roomIdCtrl.text.trim()),
              child: const Text('참여'),
            ),
          ],
        );
      },
    );
    if (id == null || id.isEmpty || !mounted) return;
    _roomIdCtrl.text = id;
    if (kIsWeb) WebSharedCamera.instance.openFromUserGesture();
    await _joinRoom();
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

  void _copyRoomId() {
    final id = _controller.roomId;
    if (id == null) return;
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('방 ID가 클립보드에 복사됐어요.'), duration: Duration(seconds: 2)),
    );
  }

  void _showInviteSheet(String roomId) {
    StudyRoomInviteSheet.show(context, roomId: roomId);
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
            Text(
              '셋터디 시작',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
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
          decoration: const InputDecoration(
            hintText: '입장 코드를 붙여넣기 해주세요',
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
                IconButton(
                  tooltip: '입장코드 공유',
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  onPressed: () {
                    final id = _controller.roomId;
                    if (id != null) {
                      _showInviteSheet(id);
                    }
                  },
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
                    _roomIdCtrl.text = room.roomId;
                    if (kIsWeb) {
                      WebSharedCamera.instance.openFromUserGesture();
                    }
                    unawaited(_joinRoomById(room.roomId, room.goalText));
                  },
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
