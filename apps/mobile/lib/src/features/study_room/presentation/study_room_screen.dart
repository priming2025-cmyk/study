import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/ui/app_snacks.dart';
import '../infra/study_room_controller.dart';
import 'premium_video_sheet.dart';
import 'video_tile.dart';

class StudyRoomScreen extends StatelessWidget {
  const StudyRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StudyRoomView();
  }
}

class _StudyRoomView extends StatefulWidget {
  const _StudyRoomView();

  @override
  State<_StudyRoomView> createState() => _StudyRoomViewState();
}

class _StudyRoomViewState extends State<_StudyRoomView> {
  final _controller = StudyRoomController();
  final _roomName = TextEditingController(text: '우리방');
  final _roomId = TextEditingController();

  final _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  bool _joining = false;
  String? _activeRoomId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    _controller.remoteStreams.listen((streams) async {
      // Update remote renderers
      for (final entry in streams.entries) {
        final id = entry.key;
        final stream = entry.value;
        final r = _remoteRenderers[id] ?? RTCVideoRenderer();
        if (!_remoteRenderers.containsKey(id)) {
          await r.initialize();
          _remoteRenderers[id] = r;
        }
        r.srcObject = stream;
      }

      // Dispose renderers for peers that left
      final missing = _remoteRenderers.keys.where((k) => !streams.containsKey(k)).toList();
      for (final k in missing) {
        final r = _remoteRenderers.remove(k);
        await r?.dispose();
      }

      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _roomName.dispose();
    _roomId.dispose();
    _controller.dispose();
    _localRenderer.dispose();
    for (final r in _remoteRenderers.values) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (!FeatureFlags.premiumVideoEnabled) {
      await showPremiumVideoSheet(context);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _joining = true);
    try {
      final roomId = await _controller.createAndJoinRoom(
        name: _roomName.text.trim().isEmpty ? '스터디방' : _roomName.text.trim(),
      );
      _localRenderer.srcObject = _controller.localStream;
      setState(() => _activeRoomId = roomId);
    } catch (e) {
      AppSnacks.showWithMessenger(messenger, '방 생성 실패: $e');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _joinRoom() async {
    if (!FeatureFlags.premiumVideoEnabled) {
      await showPremiumVideoSheet(context);
      return;
    }
    final roomId = _roomId.text.trim();
    if (roomId.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _joining = true);
    try {
      await _controller.joinRoom(roomId: roomId);
      _localRenderer.srcObject = _controller.localStream;
      setState(() => _activeRoomId = roomId);
    } catch (e) {
      AppSnacks.showWithMessenger(messenger, '참여 실패: $e');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _leave() async {
    await _controller.leave();
    _localRenderer.srcObject = null;
    if (!mounted) return;
    setState(() => _activeRoomId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스터디방(베타)'),
        actions: [
          if (_activeRoomId != null)
            TextButton(
              onPressed: _leave,
              child: const Text('나가기'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_activeRoomId == null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FeatureFlags.premiumVideoEnabled
                                ? Icons.videocam
                                : Icons.lock_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              FeatureFlags.premiumVideoEnabled
                                  ? 'Premium · 영상 스터디 활성화됨'
                                  : '영상 스터디 · Premium 전용',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        FeatureFlags.premiumVideoEnabled
                            ? '방을 만들거나 ID로 참여해 주세요.'
                            : '무료로는 「집중 세션」에서 실시간으로 같이 공부 중인 인원을 볼 수 있어요.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      if (!FeatureFlags.premiumVideoEnabled) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.go('/session'),
                          icon: const Icon(Icons.timer_outlined),
                          label: const Text('집중 세션 가기'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _roomName,
                decoration: const InputDecoration(labelText: '새 방 이름'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _joining ? null : _createRoom,
                child: Text(_joining ? '처리중...' : '방 만들기(최대 4인)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _roomId,
                decoration: const InputDecoration(labelText: '방 ID로 참여'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _joining ? null : _joinRoom,
                child: const Text('참여하기'),
              ),
              const SizedBox(height: 16),
              const Text(
                '영상 연결 시: 서버에는 시그널링만 올리고, 영상은 P2P입니다.\n'
                'TURN은 .env 에 넣었을 때만 사용됩니다.',
              ),
            ] else ...[
              Text('Room: $_activeRoomId', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    VideoTile(label: '나', renderer: _localRenderer),
                    for (final entry in _remoteRenderers.entries)
                      VideoTile(label: entry.key, renderer: entry.value),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

