import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/shell_branch_index_provider.dart';
import '../../../core/ui/app_snacks.dart';
import '../../session/domain/engaged_time_threshold.dart';
import '../../session/presentation/widgets/engaged_sensitivity_metro_card.dart';
import '../../session/infra/web_shared_camera.dart';
import '../infra/study_room_controller.dart';
import '../infra/study_room_recent_room.dart';
import 'widgets/settudy_social_view.dart';
import 'widgets/study_room_active_view.dart';
import 'widgets/study_room_ambient_sheet.dart';
import 'widgets/study_room_goal_sheet.dart';
import 'widgets/study_room_host_sheet.dart';

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
  late Future<(String roomId, String goalText)?> _recentFuture;

  late final ValueNotifier<int> _engagedMinScoreN =
      ValueNotifier(kDefaultEngagedMinScore);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _recentFuture = loadRecentStudyRoom();
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

  Future<void> _openSensitivitySheet() async {
    final cur = _engagedMinScoreN.value;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: EngagedSensitivityMetroCard(
            engagedMinScore: cur,
            onSelect: (v) async {
              await saveEngagedMinScore(v);
              _engagedMinScoreN.value = v;
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ),
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
        await saveRecentStudyRoom(roomId: roomId, goalText: goal);
        _recentFuture = loadRecentStudyRoom();
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
      await saveRecentStudyRoom(roomId: id, goalText: goal);
      _recentFuture = loadRecentStudyRoom();
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
      await saveRecentStudyRoom(roomId: rid, goalText: goal);
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

  Future<void> _leave() async {
    await _controller.leave();
  }

  void _copyRoomId() {
    final id = _controller.roomId;
    if (id == null) return;
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('방 ID가 클립보드에 복사됐어요.'), duration: Duration(seconds: 2)),
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
        unawaited(_leave());
      }
    });

    return Scaffold(
      // 키보드가 올라와도 본문(2×2·카메라) 높이를 줄이지 않음 → 채팅 입력 시 레이아웃이 덜 흔들림
      resizeToAvoidBottomInset: !inRoom,
      appBar: inRoom
          ? AppBar(
              title: const Text('셋터디'),
              actions: [
                IconButton(
                  tooltip: '집중민감도',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: _openSensitivitySheet,
                ),
                IconButton(
                  tooltip: '집중 배경음',
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
                  tooltip: '셋 ID 복사',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: _copyRoomId,
                ),
              ],
            )
          : null,
      floatingActionButton: !inRoom
          ? GestureDetector(
              onLongPress: _controller.joining
                  ? null
                  : () => _showJoinByIdDialog(context),
              child: FloatingActionButton(
                onPressed: _controller.joining
                    ? null
                    : () {
                        if (kIsWeb) {
                          WebSharedCamera.instance.openFromUserGesture();
                        }
                        unawaited(_createRoom());
                      },
                child: _controller.joining
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add),
              ),
            )
          : null,
      body: inRoom
          ? StudyRoomActiveView(
              controller: _controller,
              studyCameraSlotActive: studyCameraSlotActive,
              engagedMinListenable: _engagedMinScoreN,
            )
          : FutureBuilder<(String roomId, String goalText)?>(
              future: _recentFuture,
              builder: (context, snap) {
                final recentId = snap.data?.$1;
                return SettudySocialView(
                  joining: _controller.joining,
                  onCreateRoom: () {
                    if (kIsWeb) {
                      WebSharedCamera.instance.openFromUserGesture();
                    }
                    unawaited(_createRoom());
                  },
                  recentRoomId: recentId,
                  onQuickJoinRecent: recentId == null
                      ? null
                      : () {
                          if (kIsWeb) {
                            WebSharedCamera.instance.openFromUserGesture();
                          }
                          unawaited(_quickJoinRecent());
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
                onPressed: _leave,
                icon: const Icon(Icons.exit_to_app_rounded),
                label: const Text('셋 나가기'),
              ),
            )
          : null,
    );
  }
}
