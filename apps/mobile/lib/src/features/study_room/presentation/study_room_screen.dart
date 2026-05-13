import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/app_snacks.dart';
import '../infra/study_room_controller.dart';
import '../infra/study_room_recent_room.dart';
import 'widgets/study_room_lobby_view.dart';
import 'widgets/study_room_active_view.dart';
import 'widgets/study_room_goal_sheet.dart';

class StudyRoomScreen extends StatefulWidget {
  final bool quickJoin;
  const StudyRoomScreen({super.key, this.quickJoin = false});

  @override
  State<StudyRoomScreen> createState() => _StudyRoomScreenState();
}

class _StudyRoomScreenState extends State<StudyRoomScreen> {
  final _controller = StudyRoomController();
  final _roomNameCtrl = TextEditingController(text: '우리방');
  final _roomIdCtrl = TextEditingController();
  late Future<(String roomId, String goalText)?> _recentFuture;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _recentFuture = loadRecentStudyRoom();
    if (widget.quickJoin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _quickJoinRecent();
      });
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _roomNameCtrl.dispose();
    _roomIdCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
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
    return Scaffold(
      appBar: AppBar(
        title: Text(inRoom ? '스터디방' : '스터디방 참여'),
        actions: [
          if (inRoom)
            IconButton(
               tooltip: '방 ID 복사',
              icon: const Icon(Icons.copy_rounded),
              onPressed: _copyRoomId,
            ),
        ],
      ),
      body: inRoom
          ? StudyRoomActiveView(controller: _controller)
          : FutureBuilder<(String roomId, String goalText)?>(
              future: _recentFuture,
              builder: (context, snap) {
                final recentId = snap.data?.$1;
                return StudyRoomLobbyView(
                  roomNameCtrl: _roomNameCtrl,
                  roomIdCtrl: _roomIdCtrl,
                  joining: _controller.joining,
                  onCreate: _createRoom,
                  onJoin: _joinRoom,
                  recentRoomId: recentId,
                  onQuickJoinRecent: recentId == null ? null : _quickJoinRecent,
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
                label: const Text('방 나가기'),
              ),
            )
          : null,
    );
  }
}
