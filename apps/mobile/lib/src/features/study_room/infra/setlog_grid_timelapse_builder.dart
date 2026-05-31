import '../domain/celolog_export_speed.dart';
import '../domain/study_room_photo_snap_row.dart';

import 'setlog_grid_timelapse_builder_io.dart'
    if (dart.library.html) 'setlog_grid_timelapse_builder_web.dart';

/// 한 슬롯(1명)의 정보
class GridMemberSlot {
  final String userId;
  final String? displayName;

  const GridMemberSlot({
    required this.userId,
    this.displayName,
  });
}

/// 그리드 타임랩스 빌더 입력
class GridBuildInput {
  /// 슬롯 순서: 나(selfId)가 [0], 이후 peers 순서
  final List<GridMemberSlot> slots;

  /// 방 전체 멤버의 오늘 사진 스냅
  final List<StudyRoomPhotoSnapRow> allPhotos;

  final DateTime downloadedAt;

  final CelologExportSpeed speed;

  final int fps;
  final int width;
  final int height;
  final int videoBitrate;

  const GridBuildInput({
    required this.slots,
    required this.allPhotos,
    required this.downloadedAt,
    this.speed = CelologExportSpeed.x2,
    this.fps = 30,
    this.width = 720,
    this.height = 1280,
    this.videoBitrate = 1500000,
  });
}

/// 플랫폼별 구현을 조건부 import로 선택.
abstract final class SetlogGridTimelapseBuilder {
  static Future<String?> buildAndSave({
    required GridBuildInput input,
  }) =>
      SetlogGridTimelapseBuilderImpl.buildAndSave(input: input);
}
