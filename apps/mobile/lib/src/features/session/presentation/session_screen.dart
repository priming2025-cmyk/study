import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/ui/app_snacks.dart';
import '../domain/attention_scoring.dart';
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
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await _c.init();
    } catch (_) {}
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
    final score = s?.averageScore ?? 100;
    final status = s?.lastStatus ?? FocusStatus.focused;

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
          // ── 집중도 카드 ────────────────────────────────────────
          if (running)
            _ConcentrationCard(
              score: score,
              status: status,
              focusedSeconds: focused,
              unfocusedSeconds: unfocused,
              isWeb: kIsWeb,
            ),
          if (!running)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  '세션을 시작하면 카메라로 집중도를 측정합니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          // ── 카메라 미리보기 ────────────────────────────────────
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
}

// ── 집중도 카드 위젯 ───────────────────────────────────────────

class _ConcentrationCard extends StatelessWidget {
  final int score;
  final FocusStatus status;
  final int focusedSeconds;
  final int unfocusedSeconds;
  final bool isWeb;

  const _ConcentrationCard({
    required this.score,
    required this.status,
    required this.focusedSeconds,
    required this.unfocusedSeconds,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(cs);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // 집중도 원형 게이지
                _ScoreRing(score: score, color: statusColor),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상태 뱃지
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.label,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TimeStat(
                          label: '집중',
                          seconds: focusedSeconds,
                          color: cs.primary),
                      const SizedBox(height: 4),
                      _TimeStat(
                          label: '이탈',
                          seconds: unfocusedSeconds,
                          color: cs.error),
                    ],
                  ),
                ),
              ],
            ),
            if (isWeb) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text(
                '브라우저에서는 카메라 집중도 측정이 제공되지 않아요. '
                '정확한 측정은 앱(iOS/Android)을 이용해 주세요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ],
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
        Text(
          '$label  ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
          style: Theme.of(context).textTheme.bodyMedium,
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
