import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../infra/web_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/providers/shell_branch_index_provider.dart';
import '../../../core/ui/app_snacks.dart';
import '../../plan/data/plan_models.dart';
import '../../plan/presentation/widgets/plan_add_item_sheet.dart';
import '../../study_room/infra/study_room_ambient_player.dart';
import '../../study_room/presentation/widgets/study_room_ambient_sheet.dart';
import '../domain/attention_scoring.dart';
import '../infra/session_self_camera.dart';
import 'session_controller.dart';
import 'widgets/engaged_sensitivity_metro_card.dart';
import 'widgets/session_end_result_sheet.dart';
import 'widgets/session_bottom_bars.dart';
import 'widgets/subject_picker_card.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final bool autoStart;
  const SessionScreen({super.key, this.autoStart = false});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  late final SessionController _c;
  late final _LifecycleObserver _lifecycleObserver;
  final _ambientPlayer = StudyRoomAmbientPlayer();
  bool _autoStarted = false;
  bool _autoStartOpenedAddSheet = false;

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

  @override
  void dispose() {
    _c.dispose();
    _ambientPlayer.dispose();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  Future<void> _openSensitivitySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: EngagedSensitivityMetroCard(
            engagedMinScore: _c.engagedMinScore,
            onSelect: (v) async {
              _c.setEngagedMinScore(v);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _init() async {
    try {
      await _c.init();
      if (!mounted) return;
      if (widget.autoStart && !_autoStarted) {
        _autoStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _start();
        });
      }
    } catch (_) {}
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    // 공부 세션 실행 상태를 전역 Provider에 동기화 (AppShell이 탭 전환 시 확인에 사용)
    ref.read(sessionRunningProvider.notifier).state = _c.running;
  }

  void _openSessionAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => PlanAddItemSheet(
        planDay: DateTime.now(),
        recentSubjects: _c.recentSubjects,
        onAdd: ({
          required String subject,
          required int targetMinutes,
          TimeOfDay? startTime,
          required bool reminderEnabled,
        }) =>
            _c.addItemAndSelect(
              subject: subject,
              targetMinutes: targetMinutes,
              startTime: startTime,
              reminderEnabled: reminderEnabled,
            ),
      ),
    );
  }

  void _openSessionEditSheet(PlanItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => PlanAddItemSheet(
        planDay: DateTime.now(),
        editItem: item,
        recentSubjects: _c.recentSubjects,
        onAdd: ({
          required String subject,
          required int targetMinutes,
          TimeOfDay? startTime,
          required bool reminderEnabled,
        }) =>
            _c.updatePlanItem(
              item: item,
              subject: subject,
              targetMinutes: targetMinutes,
              startTime: startTime,
              reminderEnabled: reminderEnabled,
            ),
      ),
    );
  }

  Future<void> _onDeleteSessionPlanItem(PlanItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 과목을 삭제할까요?'),
        content: Text('「${item.subject}」이(가) 오늘 계획에서 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _c.deletePlanItem(item);
    } catch (e) {
      AppSnacks.showWithMessenger(messenger, '삭제 실패: $e');
    }
  }

  Future<void> _start() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _c.start();
    } catch (e) {
      // 퀵스타트(autoStart)에서 과목이 없는 경우: 스낵 대신 바로 추가 시트로 유도.
      if (widget.autoStart &&
          !_autoStartOpenedAddSheet &&
          e is StateError &&
          (e.message.contains('과목') || e.message.contains('선택') || e.message.contains('추가'))) {
        _autoStartOpenedAddSheet = true;
        _openSessionAddSheet();
        return;
      }
      AppSnacks.showWithMessenger(messenger, '시작 실패: $e');
    }
  }

  Future<void> _stopAndUpload() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final summary = await _c.stop();
      final reward = await _c.uploadAndApply(summary);
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
      AppSnacks.showWithMessenger(messenger, '업로드 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _c.state;
    final running = _c.running;
    final focused = running ? (s?.focusedSeconds ?? 0) : 0;
    final unfocused = running ? (s?.unfocusedSeconds ?? 0) : 0;
    final score = s?.averageScore ?? 0;
    // 배지는 센서 signals 기준으로 즉시 반영(1초 tick만 쓰면 iOS에서 얼굴 이탈 후에도 ‘집중’이 남는 것처럼 보임)
    final status = !running
        ? FocusStatus.normal
        : (s?.paused == true
            ? (s?.lastStatus ?? FocusStatus.normal)
            : AttentionScoring.liveStatusFor(
                _c.signals,
                _c.engagedMinScore,
                sensorReady: _c.attentionSensorReady,
                cameraActive: _c.cameraActive,
              ));

    ref.listen<int>(shellBranchIndexProvider, (prev, next) {
      // AppShell 탭 전환 가드가 최신 running 값을 읽을 수 있도록 항상 동기화
      ref.read(sessionRunningProvider.notifier).state = _c.running;
      if (prev == null) return;
      if (prev == kShellBranchSession && next != kShellBranchSession) {
        unawaited(_c.suspendCameraForShellNavigation());
      }
      if (next == kShellBranchSession &&
          prev != kShellBranchSession &&
          _c.running &&
          !kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          if (!mounted) return;
          await _c.resumeCameraAfterShellNavigation();
        });
      }
    });

    // AppShell이 탭 전환 확인 다이얼로그에서 "자동 저장 후 이동"을 선택하면 트리거 발동
    ref.listen<bool>(sessionAutoSaveTriggerProvider, (prev, next) {
      if (!next) return;
      // 트리거 소비 후 저장 실행
      ref.read(sessionAutoSaveTriggerProvider.notifier).state = false;
      if (_c.running && mounted) {
        unawaited(_stopAndUpload());
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('집중 공부'),
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
              player: _ambientPlayer,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, bodyConstraints) {
          final bodyH = bodyConstraints.maxHeight.isFinite
              ? bodyConstraints.maxHeight
              : MediaQuery.sizeOf(context).height * 0.72;
          final maxW = bodyConstraints.maxWidth;
          // 좁은 세로 스트립 크기
          final stripW = (maxW * 0.46).clamp(200.0, 272.0);
          var stripH = stripW * 16 / 9;
          stripH = stripH.clamp(280.0, (bodyH * 0.50).clamp(300.0, 480.0));
          final shellSession = ref.watch(shellBranchIndexProvider) == kShellBranchSession;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 스크롤 본문 ─────────────────────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
                    children: [
                      if (_c.loadingPlan && _c.todayPlan == null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(minHeight: 3),
                        ),
                      if (running) ...[
                        const SizedBox(height: 14),
                        if (_c.cameraStartError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              color: Theme.of(context).colorScheme.errorContainer,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(Icons.videocam_off_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onErrorContainer),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _c.cameraStartError!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onErrorContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (shellSession) ...[
                          if (!kIsWeb)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Center(
                                child: SizedBox(
                                  width: stripW,
                                  height: stripH,
                                  child: _NativeSessionCameraMirror(
                                    session: _c,
                                    stripW: stripW,
                                    stripH: stripH,
                                  ),
                                ),
                              ),
                            ),
                          if (kIsWeb)
                            Center(
                              child: SizedBox(
                                width: stripW,
                                height: stripH,
                                child: SessionSelfCameraSurface(
                                  width: stripW,
                                  height: stripH,
                                  appInForeground: () => _c.appInForeground,
                                  onAttentionSignals: _c.applyWebAttentionSignals,
                                ),
                              ),
                            ),
                          if (kIsWeb) const SizedBox(height: 14),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Center(
                              child: SizedBox(
                                width: stripW,
                                height: stripH * 0.35,
                                child: Card(
                                  child: Center(
                                    child: Text(
                                      '다른 탭으로 이동해 카메라를 잠시 껐어요.\n공부 탭으로 돌아오면 다시 켜져요.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        _ConcentrationCard(
                          score: score,
                          status: status,
                          focusedSeconds: focused,
                          unfocusedSeconds: unfocused,
                        ),
                      ],
                      SubjectPickerCard(
                        todayPlan: _c.todayPlan,
                        selectedPlanItemId: _c.selectedPlanItemId,
                        onSelected: _c.selectPlanItem,
                        recentSubjects: _c.recentSubjects,
                        onQuickAdd:
                            ({required String subject, required int targetMinutes}) =>
                                _c.addItemAndSelect(
                                  subject: subject,
                                  targetMinutes: targetMinutes,
                                ),
                        onOpenAdvancedAdd: _openSessionAddSheet,
                        onEditItem: _openSessionEditSheet,
                        onDeleteItem: _onDeleteSessionPlanItem,
                      ),
                      // 같이 공부 중(others) 카드 제거: 스터디방에서만 노출
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: running
            ? RunningBar(c: _c, onStop: _stopAndUpload)
            : StartBar(
                onStart: () {
                  if (kIsWeb) {
                    WebSharedCamera.instance.openFromUserGesture();
                  }
                  unawaited(_start());
                },
                starting: _c.starting,
              ),
      ),
    );
  }
}

/// 네이티브 공부 화면: 집중 중 내 화면(카메라) 미리보기.
/// [CameraController]가 [Listenable]이므로 초기화 완료 시 자동으로 다시 그립니다.
class _NativeSessionCameraMirror extends StatelessWidget {
  final SessionController session;
  final double stripW;
  final double stripH;

  const _NativeSessionCameraMirror({
    required this.session,
    required this.stripW,
    required this.stripH,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (session.frontCamera == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: cs.surfaceContainerHighest,
          child: SizedBox(
            width: stripW,
            height: stripH,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '카메라를 찾지 못했어요. 권한을 허용한 뒤 다시 시작해 주세요.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final cam = session.cameraController;
    if (cam == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: Colors.black,
          child: SizedBox(
            width: stripW,
            height: stripH,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox(
          width: stripW,
          height: stripH,
          child: ListenableBuilder(
            listenable: cam,
            builder: (context, _) {
              if (!cam.value.isInitialized) {
                return const Center(child: CircularProgressIndicator());
              }
              return _SessionCameraPreviewBox(
                key: ValueKey<int>(session.cameraPreviewGeneration),
                controller: cam,
                width: stripW,
                height: stripH,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// [CameraPreview]를 가로 좁은 스트립 안에 맞춥니다(웹·앱 공통).
class _SessionCameraPreviewBox extends StatelessWidget {
  final CameraController controller;
  final double width;
  final double height;

  const _SessionCameraPreviewBox({
    super.key,
    required this.controller,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    var ar = controller.value.aspectRatio;
    if (!ar.isFinite || ar <= 1e-6) {
      ar = 9 / 16;
    }
    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.center,
        child: SizedBox(
          width: width,
          height: width / ar,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

// ── 집중도 카드 위젯 ───────────────────────────────────────────

class _ConcentrationCard extends StatelessWidget {
  final int score;
  final FocusStatus status;
  final int focusedSeconds;
  final int unfocusedSeconds;

  const _ConcentrationCard({
    required this.score,
    required this.status,
    required this.focusedSeconds,
    required this.unfocusedSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(cs);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ScoreRing(score: score, color: statusColor),
              const SizedBox(width: 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _TimeStat(
                    label: '집중',
                    seconds: focusedSeconds,
                    color: cs.primary,
                  ),
                  const SizedBox(height: 6),
                  _TimeStat(
                    label: '이탈',
                    seconds: unfocusedSeconds,
                    color: cs.error,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(ColorScheme cs) => switch (status) {
        FocusStatus.focused => const Color(0xFF2E7D32),
        FocusStatus.normal => const Color(0xFF1565C0),
        FocusStatus.distracted => const Color(0xFFE65100),
        FocusStatus.drowsy => const Color(0xFFAD1457),
        FocusStatus.away => cs.error,
      };
}

class _ScoreRing extends StatelessWidget {
  final int score;
  final Color color;
  const _ScoreRing({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(
        painter: _RingPainter(score: score, color: color),
        child: Center(
          child: Text(
            '$score',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final int score;
  final Color color;
  const _RingPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - 10) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // 배경 트랙
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = color.withAlpha(40)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // 점수 호
    final sweep = 2 * math.pi * score / 100;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = color
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.score != score || old.color != color;
}

class _TimeStat extends StatelessWidget {
  final String label;
  final int seconds;
  final Color color;
  const _TimeStat(
      {required this.label, required this.seconds, required this.color});

  @override
  Widget build(BuildContext context) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 10),
        Text(
          '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
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
