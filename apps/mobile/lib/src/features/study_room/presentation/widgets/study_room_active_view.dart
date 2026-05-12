import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/focus_distraction_provider.dart';
import '../../../session/domain/engaged_time_threshold.dart';
import '../../../session/presentation/widgets/engaged_sensitivity_metro_card.dart';
import '../../infra/study_room_controller.dart';
import 'study_room_chat_panel.dart';
import 'study_room_ambient_sheet.dart';
import 'study_room_host_sheet.dart';
import 'study_room_main_stage.dart';

class StudyRoomActiveView extends ConsumerStatefulWidget {
  final StudyRoomController controller;

  const StudyRoomActiveView({super.key, required this.controller});

  @override
  ConsumerState<StudyRoomActiveView> createState() => _StudyRoomActiveViewState();
}

class _StudyRoomActiveViewState extends ConsumerState<StudyRoomActiveView> {
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

    final focusAsync = ref.watch(focusDistractionModeProvider);
    final dndOn = focusAsync.value ?? false;

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
              Tooltip(
                message: '채팅을 접고 방해 요소를 줄여요. 세션 탭과 같은 설정을 공유합니다.',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '방해금지',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    Switch(
                      value: dndOn,
                      onChanged: focusAsync.isLoading
                          ? null
                          : (v) => ref.read(focusDistractionModeProvider.notifier).setEnabled(v),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

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
                  ),
                ),
        ),

        StudyRoomChatPanel(
          messages: widget.controller.messages,
          selfId: selfId,
          onSendMessage: widget.controller.sendMessage,
          isFocusMode: dndOn,
        ),
      ],
    );
  }
}
