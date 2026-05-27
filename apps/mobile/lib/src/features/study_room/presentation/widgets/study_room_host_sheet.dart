import 'package:flutter/material.dart';

import '../../../../core/widgets/sheet_header_bar.dart';
import '../../infra/study_room_controller.dart';

/// 방장 전용: 다른 참가자에게 방장(호스트) 위임.
Future<void> showStudyRoomHostActionsSheet(
  BuildContext context,
  StudyRoomController controller,
) async {
  final others =
      controller.members.where((m) => m.userId != controller.selfId).toList();

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeaderBar(
                title: '방장 넘기기',
                subtitle: '선택한 멤버에게 방장 권한이 넘어가요.',
                onClose: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 4),
              if (others.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('넘길 다른 참가자가 없어요.'),
                )
              else
                ...others.map(
                  (m) => ListTile(
                    leading: const Icon(Icons.how_to_reg_outlined),
                    title: Text(m.displayName ?? m.userId.substring(0, 8)),
                    subtitle: Text('${m.userId.substring(0, 8)}…'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final err = await controller.transferRoomHostTo(m.userId);
                      if (!context.mounted) return;
                      final messenger = ScaffoldMessenger.of(context);
                      if (err != null) {
                        messenger.showSnackBar(SnackBar(content: Text(err)));
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('방장을 넘겼어요.'),
                          ),
                        );
                      }
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
