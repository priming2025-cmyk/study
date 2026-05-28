import '../domain/study_room_photo_snap_row.dart';
import '../domain/study_room_video_clip_row.dart';
import 'setlog_grid_timelapse_builder.dart';
import 'study_room_celolog_repository.dart';
import 'study_room_controller.dart';
import 'study_room_photo_snaps_repository.dart';
import 'study_room_video_clips_repository.dart';

enum CelologExportResult {
  success,
  noData,
  failed,
}

/// 셀로그 영상을 시트 없이 바로 갤러리(또는 웹 다운로드)에 저장합니다.
abstract final class StudyRoomCelologExport {
  static Future<CelologExportResult> saveTodayToGallery({
    required StudyRoomController controller,
    String? roomId,
  }) async {
    final rid = roomId ?? controller.roomId;

    late final List<StudyRoomPhotoSnapRow> photos;
    late final List<StudyRoomVideoClipRow> clips;

    if (rid != null) {
      final room = await StudyRoomCelologRepository.fetchRoomToday(roomId: rid);
      photos = room.photos;
      clips = room.clips;
    } else {
      photos = await StudyRoomPhotoSnapsRepository.fetchMyToday(roomId: null);
      clips = await StudyRoomVideoClipsRepository.fetchMyToday(roomId: null);
    }

    if (!_hasRenderableMedia(photos, clips)) {
      return CelologExportResult.noData;
    }

    final slots = _resolveSlotsWithMedia(
      controller: controller,
      photos: photos,
      clips: clips,
    );
    if (slots.isEmpty) {
      return CelologExportResult.noData;
    }

    try {
      final path = await SetlogGridTimelapseBuilder.buildAndSave(
        input: GridBuildInput(
          slots: slots,
          allPhotos: photos,
          allClips: clips,
          downloadedAt: DateTime.now(),
        ),
      );
      return path != null ? CelologExportResult.success : CelologExportResult.noData;
    } catch (_) {
      return CelologExportResult.failed;
    }
  }

  static bool _hasRenderableMedia(
    List<StudyRoomPhotoSnapRow> photos,
    List<StudyRoomVideoClipRow> clips,
  ) {
    if (photos.isNotEmpty) return true;
    return clips.any((c) => c.posterUrl?.trim().isNotEmpty == true);
  }

  /// 오늘 실제 사진·클립이 있는 멤버만 슬롯에 포함 (Presence만 있는 유령 슬롯 제외).
  static List<GridMemberSlot> _resolveSlotsWithMedia({
    required StudyRoomController controller,
    required List<StudyRoomPhotoSnapRow> photos,
    required List<StudyRoomVideoClipRow> clips,
  }) {
    final activeIds = <String>{
      for (final p in photos) p.userId,
      for (final c in clips)
        if (c.posterUrl?.trim().isNotEmpty == true) c.userId,
    };
    if (activeIds.isEmpty) return const [];

    final slotByUser = <String, GridMemberSlot>{};
    for (final uid in activeIds) {
      slotByUser[uid] = GridMemberSlot(
        userId: uid,
        displayName: controller.displayNameFor(uid),
      );
    }

    final selfId = controller.selfId;
    final ordered = <GridMemberSlot>[];
    if (selfId != null && slotByUser.containsKey(selfId)) {
      ordered.add(slotByUser.remove(selfId)!);
    }
    for (final s in controller.celologMemberSlots) {
      if (s.userId == selfId) continue;
      final slot = slotByUser.remove(s.userId);
      if (slot != null) ordered.add(slot);
    }
    ordered.addAll(slotByUser.values);
    return ordered;
  }
}
