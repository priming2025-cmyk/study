import 'package:flutter/material.dart';

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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('집중 배경음', style: Theme.of(ctx).textTheme.titleMedium),
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
