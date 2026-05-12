import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb, debugPrint;
import 'package:flutter/material.dart';

import '../../../session/domain/attention_scoring.dart';
import '../../../session/domain/attention_signals.dart';
import '../../../session/infra/face_attention_sensor.dart';
import '../../../session/infra/session_self_camera.dart';
import 'study_room_self_camera_preview_box.dart';
import 'study_room_self_focus_badge.dart';

/// 스터디방 전용: 세션과 동일한 카메라·얼굴 신호로 실시간 집중도 표시 (방 안에서만 사용).
class StudyRoomSelfLivePanel extends StatefulWidget {
  final double width;
  final double height;
  /// 세션과 동일 키의 집중민감도; 변경 시 즉시 반영.
  final ValueListenable<int> engagedMinListenable;

  const StudyRoomSelfLivePanel({
    super.key,
    required this.width,
    required this.height,
    required this.engagedMinListenable,
  });

  @override
  State<StudyRoomSelfLivePanel> createState() => _StudyRoomSelfLivePanelState();
}

class _StudyRoomSelfLifecycle extends WidgetsBindingObserver {
  _StudyRoomSelfLifecycle({required this.onForeground});
  final ValueChanged<bool> onForeground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onForeground(state == AppLifecycleState.resumed);
  }
}

class _StudyRoomSelfLivePanelState extends State<StudyRoomSelfLivePanel> {
  final FaceAttentionSensor _sensor = FaceAttentionSensor();
  StreamSubscription<AttentionSignals>? _sub;
  Timer? _tick;

  AttentionScoringState? _scoreState;
  AttentionSignals _signals = const AttentionSignals(
    facePresent: true,
    multiFace: false,
    appInForeground: true,
  );
  bool _appInForeground = true;
  late final _StudyRoomSelfLifecycle _life = _StudyRoomSelfLifecycle(
    onForeground: (v) {
      _appInForeground = v;
      _signals = AttentionSignals(
        facePresent: _signals.facePresent,
        multiFace: _signals.multiFace,
        appInForeground: v,
        earLeft: _signals.earLeft,
        earRight: _signals.earRight,
        headYaw: _signals.headYaw,
        headPitch: _signals.headPitch,
        blinkFrame: _signals.blinkFrame,
      );
    },
  );

  CameraDescription? _frontCam;

  int _engagedMinScoreForTick() => widget.engagedMinListenable.value;

  void _onEngagedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.engagedMinListenable.addListener(_onEngagedChanged);
    WidgetsBinding.instance.addObserver(_life);
    unawaited(_boot());
  }

  Future<void> _boot() async {
    if (kIsWeb) {
      _scoreState = AttentionScoringState.started(DateTime.now());
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
      if (mounted) setState(() {});
      return;
    }

    try {
      final cams = await availableCameras();
      final front =
          cams.where((c) => c.lensDirection == CameraLensDirection.front).toList();
      _frontCam = front.isNotEmpty ? front.first : (cams.isNotEmpty ? cams.first : null);
    } catch (e) {
      debugPrint('[StudyRoomSelfLivePanel] cameras: $e');
    }
    if (!mounted) return;

    if (_frontCam != null) {
      try {
        await _sub?.cancel();
        _sub = _sensor.stream.listen((s) {
          _signals = s;
          if (mounted) setState(() {});
        });
        await _sensor.start(
          camera: _frontCam,
          appInForeground: () => _appInForeground,
        );
      } catch (e, st) {
        debugPrint('[StudyRoomSelfLivePanel] sensor: $e\n$st');
        await _sub?.cancel();
        _sub = null;
        await _sensor.stop();
      }
    }

    if (!mounted) return;
    _scoreState = AttentionScoringState.started(DateTime.now());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    setState(() {});
  }

  void _onTick() {
    final st = _scoreState;
    if (st == null) return;
    _scoreState = AttentionScoring.tick(
      state: st,
      now: DateTime.now(),
      signals: _signals,
      engagedMinScore: _engagedMinScoreForTick(),
    );
    if (mounted) setState(() {});
  }

  void _applyWebSignals(AttentionSignals s) {
    _signals = s;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.engagedMinListenable.removeListener(_onEngagedChanged);
    WidgetsBinding.instance.removeObserver(_life);
    _tick?.cancel();
    unawaited(_sub?.cancel());
    _sub = null;
    unawaited(_sensor.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = _scoreState?.averageScore ?? 100;
    final status = _scoreState?.lastStatus ?? FocusStatus.focused;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (kIsWeb)
              SessionSelfCameraSurface(
                width: widget.width,
                height: widget.height,
                appInForeground: () => _appInForeground,
                onAttentionSignals: _applyWebSignals,
              )
            else
              StudyRoomSelfCameraPreviewBox(
                sensor: _sensor,
                width: widget.width,
                height: widget.height,
              ),
            StudyRoomSelfFocusBadge(score: score, status: status),
          ],
        ),
      ),
    );
  }
}
