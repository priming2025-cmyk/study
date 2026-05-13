import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../session/domain/engaged_time_threshold.dart';
import '../../../session/presentation/widgets/engaged_sensitivity_metro_card.dart';
import '../../infra/study_room_controller.dart';
import 'study_room_chat_panel.dart';
import 'study_room_ambient_sheet.dart';
import 'study_room_host_sheet.dart';
import 'study_room_main_stage.dart';

class StudyRoomActiveView extends StatefulWidget {
  final StudyRoomController controller;
  final bool studyCameraSlotActive;

  const StudyRoomActiveView({
    super.key,
    required this.controller,
    required this.studyCameraSlotActive,
  });

  @override
  State<StudyRoomActiveView> createState() => _StudyRoomActiveViewState();
}

class _StudyRoomActiveViewState extends State<StudyRoomActiveView> {
  late final ValueNotifier<int> _engagedMinScoreN =
      ValueNotifier(kDefaultEngagedMinScore);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final v = await loadEngagedMinScore();
      if (!mounted) return;
      _engagedMinScoreN.value = v;
    });
  }

  @override
  void dispose() {
    _engagedMinScoreN.dispose();
    super.dispose();
  }

  Future<void> _openSensitivitySheet(BuildContext context) async {
    final cur = _engagedMinScoreN.value;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: EngagedSensitivityMetroCard(
            engagedMinScore: cur,
            onSelect: (v) async {
              await saveEngagedMinScore(v);
              _engagedMinScoreN.value = v;
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.controller.members;
    final selfId = widget.controller.selfId ?? '';
    final roomId = widget.controller.roomId ?? '';

    // 채팅 영역은 화면의 22% (최소 140px, 최대 200px)로 제한해 2×2 그리드가 눌리지 않도록 함
    final mediaH = MediaQuery.sizeOf(context).height;
    final chatAreaH = math.min(200.0, math.max(140.0, mediaH * 0.22));

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                tooltip: '집중민감도',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => _openSensitivitySheet(context),
              ),
              IconButton(
                tooltip: '집중 배경음',
                icon: const Icon(Icons.graphic_eq_rounded),
                onPressed: () => showStudyRoomAmbientSheet(
                  context,
                  player: widget.controller.ambient,
                ),
              ),
              if (widget.controller.isRoomHost)
                IconButton(
                  tooltip: '방장 넘기기',
                  icon: const Icon(Icons.swap_horiz_rounded),
                  onPressed: () => showStudyRoomHostActionsSheet(context, widget.controller),
                ),
              Expanded(
                child: Text(
                  '방 ID: $roomId',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Column(
            children: [
              Expanded(
                child: members.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              '멤버 정보를 불러오는 중…',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: StudyRoomMainStage(
                          controller: widget.controller,
                          engagedMinListenable: _engagedMinScoreN,
                          studyCameraSlotActive: widget.studyCameraSlotActive,
                        ),
                      ),
              ),
              SizedBox(
                height: chatAreaH,
                width: double.infinity,
                child: StudyRoomChatPanel(
                  messages: widget.controller.messages,
                  selfId: selfId,
                  onSendMessage: widget.controller.sendMessage,
                  isFocusMode: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
