import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb, debugPrint;
import 'package:flutter/material.dart';

import '../../../session/domain/attention_scoring.dart';
import '../../../session/domain/attention_signals.dart';
import '../../../session/infra/attention_camera_service.dart';
import '../../../session/infra/session_camera_cache.dart';
import '../../../session/infra/session_self_camera.dart';
import 'study_room_self_camera_preview_box.dart';
import 'study_room_self_focus_badge.dart';

/// 스터디방 전용: 단일 [AttentionCameraService]로 실시간 집중도 표시.
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
  final AttentionCameraService _camera = AttentionCameraService.instance;
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
  bool _ownsCamera = false;

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

  int _engagedMinScoreForTick() => widget.engagedMinListenable.value;

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  bool get _cameraActive => !kIsWeb && _camera.hasActiveCamera;

  bool get _sensorReadyForUi {
    if (kIsWeb || !_isIOS) return _cameraActive;
    final t = _cameraLiveAt;
    if (t == null || !_cameraActive) return false;
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
    if (_ownsCamera) {
      await _camera.release();
      _ownsCamera = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _boot() async {
    if (!widget.cameraSlotActive) return;
    await _releaseSlot();
    if (!kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted || !widget.cameraSlotActive) return;

    if (kIsWeb) {
      _scoreState = AttentionScoringState.started(DateTime.now());
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
      if (mounted) setState(() {});
      return;
    }

    CameraDescription? frontCam;
    try {
      frontCam = await SessionCameraCache.getFrontOrDefault();
    } catch (e) {
      debugPrint('[StudyRoomSelfLivePanel] cameras: $e');
    }
    if (!mounted || !widget.cameraSlotActive) return;

    if (frontCam != null) {
      try {
        await _camera.acquire(
          camera: frontCam,
          appInForeground: () => _appInForeground,
        );
        _ownsCamera = true;
        if (!mounted || !widget.cameraSlotActive) {
          await _camera.release();
          _ownsCamera = false;
          return;
        }
        _cameraLiveAt = DateTime.now();
        _sub = _camera.stream.listen((s) {
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
        if (_ownsCamera) {
          await _camera.release();
          _ownsCamera = false;
        }
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
      cameraActive: _cameraActive,
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
                key: ValueKey<int>(_camera.previewGeneration),
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
