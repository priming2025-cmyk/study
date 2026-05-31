import '../domain/celolog_export_speed.dart';
import '../domain/study_room_photo_snap_row.dart';
import 'setlog_grid_timelapse_builder.dart';
import 'study_room_celolog_repository.dart';
import 'study_room_controller.dart';

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
    CelologExportSpeed speed = CelologExportSpeed.x2,
  }) async {
    final rid = roomId ?? controller.roomId;

    final List<StudyRoomPhotoSnapRow> photos;
    if (rid != null) {
      final room = await StudyRoomCelologRepository.fetchRoomToday(roomId: rid);
      photos = room.photos;
    } else {
      return CelologExportResult.noData;
    }

    if (photos.isEmpty) {
      return CelologExportResult.noData;
    }

    final slots = _resolveRoomSlots(controller: controller);
    if (slots.isEmpty) {
      return CelologExportResult.noData;
    }

    try {
      final path = await SetlogGridTimelapseBuilder.buildAndSave(
        input: GridBuildInput(
          slots: slots,
          allPhotos: photos,
          downloadedAt: DateTime.now(),
          speed: speed,
        ),
      );
      return path != null ? CelologExportResult.success : CelologExportResult.noData;
    } catch (_) {
      return CelologExportResult.failed;
    }
  }

  /// 방 멤버 고정 순서(나 → peers). 사진 유무와 관계없이 슬롯 유지.
  static List<GridMemberSlot> _resolveRoomSlots({
    required StudyRoomController controller,
  }) {
    final ordered = <GridMemberSlot>[];
    for (final s in controller.celologMemberSlots) {
      ordered.add(
        GridMemberSlot(
          userId: s.userId,
          displayName: s.displayName ?? controller.displayNameFor(s.userId),
        ),
      );
    }
    return ordered;
  }
}
