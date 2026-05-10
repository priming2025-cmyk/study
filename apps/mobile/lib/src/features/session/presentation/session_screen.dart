import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/ui/app_snacks.dart';
import 'session_controller.dart';
import 'widgets/others_studying_card.dart';
import 'widgets/session_bottom_bars.dart';
import 'widgets/subject_picker_card.dart';

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  late final SessionController _c;
  late final _LifecycleObserver _lifecycleObserver;

  @override
  void dispose() {
    _c.dispose();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _c = SessionController(
      planRepo: ref.read(planRepositoryProvider),
    )..addListener(_onChanged);
    _lifecycleObserver = _LifecycleObserver(
      onChanged: (inForeground) {
        if (!mounted) return;
        _c.appInForeground = inForeground;
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _init();
  }

  Future<void> _init() async {
    try {
      await _c.init();
    } catch (_) {
    }
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _start() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _c.start();
    } catch (e) {
      AppSnacks.showWithMessenger(messenger, '시작 실패: $e');
    }
  }

  Future<void> _stopAndUpload() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final summary = await _c.stop();
      await _c.uploadAndApply(summary);
      AppSnacks.showWithMessenger(messenger, '종료 완료 · 계획에 자동 반영했어요');
    } catch (e) {
      AppSnacks.showWithMessenger(messenger, '업로드 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _c.state;
    final running = _c.running;
    final focused = running ? (s?.focusedSeconds ?? 0) : 0;
    final unfocused = running ? (s?.unfocusedSeconds ?? 0) : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('집중 세션')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_c.loadingPlan && _c.todayPlan == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          SubjectPickerCard(
            todayPlan: _c.todayPlan,
            selectedPlanItemId: _c.selectedPlanItemId,
            onSelected: _c.selectPlanItem,
            newSubjectController: _c.newSubjectController,
            quickMinutes: _c.quickMinutes,
            onQuickMinutesChanged: (m) => setState(() => _c.quickMinutes = m),
            onAddAndSelect: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _c.addPlannedSubjectAndSelect();
              } catch (e) {
                AppSnacks.showWithMessenger(messenger, '추가 실패: $e');
              }
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('집중: ${_formatSeconds(focused)}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('이탈: ${_formatSeconds(unfocused)}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(
                    '세션 신뢰도(베타): ${_c.signals.facePresent && !_c.signals.multiFace ? 'OK' : 'UNCERTAIN'}',
                  ),
                  if (kIsWeb) ...[
                    const SizedBox(height: 8),
                    Text(
                      '브라우저에서는 카메라·ML 검증 없이 타이머만 동작합니다. 정확한 집중 측정은 앱에서 해 주세요.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!kIsWeb &&
              running &&
              _c.cameraController != null &&
              _c.cameraController!.value.isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: _c.cameraController!.value.aspectRatio,
                child: CameraPreview(_c.cameraController!),
              ),
            ),
          if (running) ...[
            const SizedBox(height: 12),
            OthersStudyingCard(others: _c.others),
          ],
          const SizedBox(height: 96),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: running
            ? RunningBar(c: _c, onStop: _stopAndUpload)
            : StartBar(onStart: _start, starting: _c.starting),
      ),
    );
  }

  String _formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _LifecycleObserver extends WidgetsBindingObserver {
  final void Function(bool inForeground) onChanged;
  _LifecycleObserver({required this.onChanged});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onChanged(state == AppLifecycleState.resumed);
  }
}

