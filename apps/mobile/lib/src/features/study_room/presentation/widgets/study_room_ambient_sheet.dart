import 'package:flutter/material.dart';

import '../../../../core/widgets/sheet_header_bar.dart';
import '../../infra/study_room_ambient_player.dart';

Future<void> showStudyRoomAmbientSheet(
  BuildContext context, {
  required StudyRoomAmbientPlayer player,
}) async {
  final picked = await showModalBottomSheet<StudyRoomAmbientTrack>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeaderBar(
              title: '집중 배경음',
              onClose: () => Navigator.of(ctx).pop(),
            ),
            for (final t in StudyRoomAmbientTrack.values)
              ListTile(
                leading: Icon(switch (t) {
                  StudyRoomAmbientTrack.none => Icons.volume_off_outlined,
                  StudyRoomAmbientTrack.rain => Icons.water_drop_outlined,
                  StudyRoomAmbientTrack.cafe => Icons.local_cafe_outlined,
                  StudyRoomAmbientTrack.white => Icons.graphic_eq,
                  StudyRoomAmbientTrack.lofi => Icons.music_note_outlined,
                }),
                title: Text(t.labelKo),
                trailing: player.current == t ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(ctx).pop(t),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (picked != null) {
    await player.setTrack(picked);
  }
}
