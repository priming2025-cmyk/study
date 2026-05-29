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
import 'study_room_group_chat_chip.dart';
import 'study_room_self_focus_badge.dart';
/// 스터디방 본인 실시간 프리뷰 — [AttentionCameraService] 단일 인스턴스 공유.
/// 다른 탭으로 나갈 때는 카메라를 **끄지 않고** 구독만 끊습니다(공부 탭과 동일).
class StudyRoomSelfLivePanel extends StatefulWidget {
  final StudyRoomController controller;
  final double width;
  final double height;
  final bool cameraSlotActive;
  final ValueListenable<int> engagedMinListenable;
  final VoidCallback? onOpenPublicMode;

  const StudyRoomSelfLivePanel({
    super.key,
    required this.controller,
    required this.width,
    required this.height,
    required this.cameraSlotActive,
    required this.engagedMinListenable,
    this.onOpenPublicMode,
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
  Timer? _streamWatchdog;
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

  /// 스트림이 살아 있으면 프리뷰 유지 (자리 이탈·신호 끊김과 무관).
  bool get _cameraActive => kIsWeb
      ? WebSharedCamera.instance.isStreamReady
      : _camera.hasActiveCamera;

  bool get _sensorReadyForUi =>
      kIsWeb ? WebSharedCamera.instance.isStreamReady : _camera.hasActiveCamera;

  void _onEngagedChanged() {
    if (mounted) setState(() {});
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.engagedMinListenable.addListener(_onEngagedChanged);
    widget.controller.addListener(_onControllerChanged);
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
    if (oldWidget.controller.webSelfCamEpoch !=
        widget.controller.webSelfCamEpoch) {
      unawaited(_boot());
    }
  }

  /// 탭 전환: 스트림 구독만 해제 (카메라 세션 유지 → 공부 탭·복귀 시 프리즈 방지).
  Future<void> _suspendForTab() async {
    _stopStreamWatchdog();
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
    _startStreamWatchdog();
  }

  void _startStreamWatchdog() {
    _streamWatchdog?.cancel();
    if (!widget.cameraSlotActive) return;
    _streamWatchdog = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !widget.cameraSlotActive) return;
      unawaited(_camera.ensurePreviewStreamRunning());
    });
  }

  void _stopStreamWatchdog() {
    _streamWatchdog?.cancel();
    _streamWatchdog = null;
  }

  Future<void> _boot() async {
    if (!widget.cameraSlotActive) return;

    if (kIsWeb) {
      WebSharedCamera.instance.openFromUserGesture();
      _startStreamWatchdog();
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
    _stopStreamWatchdog();
    widget.engagedMinListenable.removeListener(_onEngagedChanged);
    widget.controller.removeListener(_onControllerChanged);
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
                  _SelfPanelBottomOverlays(
                    controller: widget.controller,
                    onOpenPublicMode: widget.onOpenPublicMode,
                  ),
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
                      'study-self-cam-${widget.controller.roomId}-${widget.controller.webSelfCamEpoch}',
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
                if (widget.controller.statusText.trim().isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        widget.controller.statusText.trim(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          height: 1.15,
                          shadows: [
                            Shadow(
                              blurRadius: 18,
                              color: Colors.black54,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                StudyRoomSelfFocusBadge(score: score, status: status),
                _SelfPanelBottomOverlays(
                  controller: widget.controller,
                  onOpenPublicMode: widget.onOpenPublicMode,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SelfPanelBottomOverlays extends StatelessWidget {
  final StudyRoomController controller;
  final VoidCallback? onOpenPublicMode;

  const _SelfPanelBottomOverlays({
    required this.controller,
    this.onOpenPublicMode,
  });

  String _publicModeLabel(String mode) => switch (mode) {
        'video' => '2초 영상',
        'rest' => '휴식',
        _ => '캡쳐',
      };

  Future<void> _editStatus(BuildContext context) async {
    final ctrl = TextEditingController(text: controller.statusText);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: 16 + bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '내 상태',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: '예: 수학 공부 중',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => Navigator.of(ctx).pop(ctrl.text.trim()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('취소'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                    child: const Text('저장'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    ctrl.dispose();
    if (result != null) {
      await controller.setMyStatusText(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 8,
          right: 8,
          left: 48,
          child: Align(
            alignment: Alignment.topRight,
            child: StudyRoomGroupChatChip(controller: controller),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 54,
          child: Material(
            color: Colors.black.withAlpha(140),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => _editStatus(context),
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      '상태',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Material(
            color: Colors.black.withAlpha(140),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: onOpenPublicMode,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_outlined,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _publicModeLabel(controller.selfPublicViewerMode),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
