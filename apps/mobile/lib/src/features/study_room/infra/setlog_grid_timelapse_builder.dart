import '../domain/study_room_photo_snap_row.dart';
import '../domain/study_room_video_clip_row.dart';

import 'setlog_grid_timelapse_builder_io.dart'
    if (dart.library.html) 'setlog_grid_timelapse_builder_web.dart';

/// 한 슬롯(1명)의 정보
class GridMemberSlot {
  final String userId;
  final String? displayName;
  // statusText는 per-photo의 status_text 컬럼을 사용, 없으면 이 값으로 폴백
  final String? statusText;

  const GridMemberSlot({
    required this.userId,
    this.displayName,
    this.statusText,
  });
}

/// 그리드 타임랩스 빌더 입력
class GridBuildInput {
  /// 슬롯 순서: 나(selfId)가 [0], 이후 peers 순서
  final List<GridMemberSlot> slots;

  /// 방 전체 멤버의 오늘 사진 스냅(study_room_photo_snaps_room_today RPC)
  final List<StudyRoomPhotoSnapRow> allPhotos;

  /// 방 전체 멤버의 오늘 영상 클립(study_room_video_clips_room_today RPC)
  final List<StudyRoomVideoClipRow> allClips;

  final DateTime downloadedAt;

  /// 프레임 레이트: 15fps × 60frames = 4초/시간
  final int fps;
  final int width;
  final int height;
  final int videoBitrate;

  const GridBuildInput({
    required this.slots,
    required this.allPhotos,
    required this.allClips,
    required this.downloadedAt,
    this.fps = 15,
    this.width = 720,
    this.height = 1280,
    this.videoBitrate = 1500000,
  });
}

/// 플랫폼별 구현을 조건부 import로 선택.
abstract final class SetlogGridTimelapseBuilder {
  /// 모든 멤버의 사진/클립을 그리드로 합성한 MP4를 갤러리에 저장.
  /// 성공 시 파일 경로 반환, 데이터 없으면 null.
  static Future<String?> buildAndSave({
    required GridBuildInput input,
  }) =>
      SetlogGridTimelapseBuilderImpl.buildAndSave(input: input);
}
