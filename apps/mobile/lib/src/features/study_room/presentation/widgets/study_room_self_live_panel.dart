import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb, debugPrint;
import 'package:flutter/material.dart';

import '../../../session/domain/attention_scoring.dart';
import '../../../session/domain/attention_signals.dart';
import '../../../session/infra/attention_camera_service.dart';
import '../../../session/infra/session_camera_cache.dart';
import '../../../session/infra/session_self_camera.dart';
import '../../../session/infra/web_camera.dart';
import '../../infra/study_room_controller.dart';
import 'study_room_self_camera_preview_box.dart';
import 'study_room_self_focus_badge.dart';

/// 스터디방 본인 실시간 프리뷰 — [AttentionCameraService] 단일 인스턴스 공유.
/// 다른 탭으로 나갈 때는 카메라를 **끄지 않고** 구독만 끊습니다(공부 탭과 동일).
class StudyRoomSelfLivePanel extends StatefulWidget {
  final StudyRoomController controller;
  final double width;
  final double height;
  final bool cameraSlotActive;
  final ValueListenable<int> engagedMinListenable;

  const StudyRoomSelfLivePanel({
    super.key,
    required this.controller,
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
  bool _appInForeground = true;
  DateTime? _lastSignalAt;
  bool _ownsCamera = false;

  late final _StudyRoomSelfLifecycle _life = _StudyRoomSelfLifecycle(
    onForeground: (v) {
      _appInForeground = v;
      widget.controller.feedFocusSignals(
        AttentionSignals(
          facePresent: widget.controller.focusSignals.facePresent,
          multiFace: widget.controller.focusSignals.multiFace,
          appInForeground: v,
          earLeft: widget.controller.focusSignals.earLeft,
          earRight: widget.controller.focusSignals.earRight,
          headYaw: widget.controller.focusSignals.headYaw,
          headPitch: widget.controller.focusSignals.headPitch,
          blinkFrame: widget.controller.focusSignals.blinkFrame,
        ),
      );
    },
  );

  int _engagedMinScoreForTick() => widget.engagedMinListenable.value;

  bool get _cameraActive => kIsWeb
      ? (WebSharedCamera.instance.isStreamReady || _hasRecentSignal)
      : _camera.hasActiveCamera;

  bool get _sensorReadyForUi => _cameraActive;

  bool get _hasRecentSignal {
    final t = _lastSignalAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(seconds: 3);
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
        unawaited(_suspendForTab());
      }
    }
  }

  /// 탭 전환: 스트림 구독만 해제 (카메라 세션 유지 → 공부 탭·복귀 시 프리즈 방지).
  Future<void> _suspendForTab() async {
    await _sub?.cancel();
    _sub = null;
    if (mounted) setState(() {});
  }

  /// 방 퇴장·위젯 dispose: 구독 해제 + 본인이 연 카메라만 release.
  Future<void> _releaseCameraFully() async {
    await _suspendForTab();
    if (_ownsCamera) {
      await _camera.release();
      _ownsCamera = false;
    }
    _lastSignalAt = null;
    if (mounted) setState(() {});
  }

  Future<void> _attachStream() async {
    await _sub?.cancel();
    _sub = _camera.stream.listen((s) {
      _lastSignalAt = DateTime.now();
      widget.controller.feedFocusSignals(s);
      if (mounted) setState(() {});
    });
  }

  Future<void> _boot() async {
    if (!widget.cameraSlotActive) return;

    if (kIsWeb) {
      WebSharedCamera.instance.openFromUserGesture();
      if (mounted) setState(() {});
      return;
    }

    if (_camera.hasActiveCamera) {
      await _attachStream();
      if (mounted) setState(() {});
      return;
    }

    await _releaseCameraFully();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted || !widget.cameraSlotActive) return;

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
        await _attachStream();
        widget.controller.feedFocusSignals(
          const AttentionSignals(
            facePresent: false,
            multiFace: false,
            appInForeground: true,
          ),
        );
      } catch (e, st) {
        debugPrint('[StudyRoomSelfLivePanel] sensor: $e\n$st');
        await _sub?.cancel();
        _sub = null;
        if (_ownsCamera) {
          await _camera.release();
          _ownsCamera = false;
        }
      }
    }

    if (mounted) setState(() {});
  }

  void _applyWebSignals(AttentionSignals s) {
    _lastSignalAt = DateTime.now();
    widget.controller.feedFocusSignals(s);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.engagedMinListenable.removeListener(_onEngagedChanged);
    WidgetsBinding.instance.removeObserver(_life);
    unawaited(_releaseCameraFully());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final score = widget.controller.focusAverageScore;
        final status = AttentionScoring.liveStatusFor(
          widget.controller.focusSignals,
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
                    key: ValueKey<String>(
                      'study-self-cam-${widget.controller.roomId}',
                    ),
                    width: widget.width,
                    height: widget.height,
                    active: true,
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
      },
    );
  }
}
