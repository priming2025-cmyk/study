import '../domain/study_room_photo_snap_row.dart';
import '../domain/study_room_video_clip_row.dart';

import 'setlog_timelapse_builder_io.dart'
    if (dart.library.html) 'setlog_timelapse_builder_web.dart';

class SetlogBuildInput {
  final List<StudyRoomPhotoSnapRow> photos;
  final List<StudyRoomVideoClipRow> clips;
  final DateTime downloadedAt;

  /// 3배속: 1분=0.1초 → fps=10, 1분당 1프레임
  final int fps;
  final int width;
  final int height;
  final int videoBitrate;

  const SetlogBuildInput({
    required this.photos,
    required this.clips,
    required this.downloadedAt,
    this.fps = 10,
    this.width = 720,
    this.height = 1280,
    this.videoBitrate = 850000,
  });
}

abstract final class SetlogTimelapseBuilder {
  static Future<String?> buildAndShare({
    required SetlogBuildInput input,
  }) =>
      SetlogTimelapseBuilderImpl.buildAndShare(input: input);
}
