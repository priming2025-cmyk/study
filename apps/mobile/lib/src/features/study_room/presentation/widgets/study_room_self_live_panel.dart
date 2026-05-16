import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb, debugPrint;
import 'package:flutter/material.dart';

import '../../../session/domain/attention_scoring.dart';
import '../../../session/domain/attention_signals.dart';
import '../../../session/infra/face_attention_sensor.dart';
import '../../../session/infra/session_camera_cache.dart';
import '../../../session/infra/session_self_camera.dart';
import 'study_room_self_camera_preview_box.dart';
import 'study_room_self_focus_badge.dart';

/// 스터디방 전용: 공부(세션)과 동일한 카메라·얼굴 신호로 실시간 집중도 표시 (방 안에서만 사용).
class StudyRoomSelfLivePanel extends StatefulWidget {
  final double width;
  final double height;
  final bool cameraSlotActive;
  final ValueListenable<int> engagedMinListenable;

  const StudyRoomSelfLivePanel({
    super.key,
    required this.width,
    required this.height,
    required this.cameraSlotActive,
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
    facePresent: false,
    multiFace: false,
    appInForeground: true,
  );
  bool _appInForeground = true;
  DateTime? _cameraLiveAt;

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

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  bool get _sensorReadyForUi {
    if (kIsWeb || !_isIOS) return true;
    final t = _cameraLiveAt;
    if (t == null) return false;
    return DateTime.now().difference(t) >= const Duration(seconds: 2);
  }

  void _onEngagedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.engagedMinListenable.addListener(_onEngagedChanged);
    WidgetsBinding.instance.addObserver(_life);
    if (widget.cameraSlotActive) {
      unawaited(_boot());
    }
  }

  @override
  void didUpdateWidget(covariant StudyRoomSelfLivePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraSlotActive != widget.cameraSlotActive) {
      if (widget.cameraSlotActive) {
        unawaited(_boot());
      } else {
        unawaited(_releaseSlot());
      }
    }
  }

  Future<void> _releaseSlot() async {
    _tick?.cancel();
    _tick = null;
    await _sub?.cancel();
    _sub = null;
    _cameraLiveAt = null;
    await _sensor.stop();
    if (mounted) setState(() {});
  }

  Future<void> _boot() async {
    if (!widget.cameraSlotActive) return;
    await _releaseSlot();
    if (!kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted || !widget.cameraSlotActive) return;

    if (kIsWeb) {
      _scoreState = AttentionScoringState.started(DateTime.now());
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
      if (mounted) setState(() {});
      return;
    }

    try {
      _frontCam = await SessionCameraCache.getFrontOrDefault();
    } catch (e) {
      debugPrint('[StudyRoomSelfLivePanel] cameras: $e');
    }
    if (!mounted || !widget.cameraSlotActive) return;

    if (_frontCam != null) {
      try {
        await _sensor.start(
          camera: _frontCam,
          appInForeground: () => _appInForeground,
        );
        if (!mounted || !widget.cameraSlotActive) {
          await _sensor.stop();
          return;
        }
        _cameraLiveAt = DateTime.now();
        _sub = _sensor.stream.listen((s) {
          _signals = s;
          if (mounted) setState(() {});
        });
        _signals = const AttentionSignals(
          facePresent: false,
          multiFace: false,
          appInForeground: true,
        );
      } catch (e, st) {
        debugPrint('[StudyRoomSelfLivePanel] sensor: $e\n$st');
        await _sub?.cancel();
        _sub = null;
        await _sensor.stop();
        _cameraLiveAt = null;
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
    final tickSignals = _sensorReadyForUi
        ? _signals
        : const AttentionSignals(
            facePresent: false,
            multiFace: false,
            appInForeground: true,
          );
    _scoreState = AttentionScoring.tick(
      state: st,
      now: DateTime.now(),
      signals: tickSignals,
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
    unawaited(_releaseSlot());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = _scoreState?.averageScore ?? 0;
    final status = AttentionScoring.liveStatusFor(
      _signals,
      _engagedMinScoreForTick(),
      sensorReady: _sensorReadyForUi,
    );

    if (!widget.cameraSlotActive) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Icon(
                  Icons.videocam_off_outlined,
                  color: Colors.white.withAlpha(70),
                  size: 28,
                ),
              ),
              StudyRoomSelfFocusBadge(score: score, status: status),
            ],
          ),
        ),
      );
    }

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
                key: ValueKey<int>(_sensor.previewGeneration),
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
