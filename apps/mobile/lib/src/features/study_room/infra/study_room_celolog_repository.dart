import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/study_room_photo_snap_row.dart';
import '../domain/study_room_video_clip_row.dart';

/// 방 전체 멤버의 오늘 셀로그 데이터(사진 + 영상 클립)를 가져옵니다.
///
/// RPC: study_room_photo_snaps_room_today / study_room_video_clips_room_today
/// (0038 마이그레이션에서 생성)
abstract final class StudyRoomCelologRepository {
  static SupabaseClient get _sb => Supabase.instance.client;

  static Future<
      ({
        List<StudyRoomPhotoSnapRow> photos,
        List<StudyRoomVideoClipRow> clips,
      })> fetchRoomToday({required String roomId}) async {
    final photosRaw = await _sb.rpc(
      'study_room_photo_snaps_room_today',
      params: {'p_room_id': roomId},
    );
    final clipsRaw = await _sb.rpc(
      'study_room_video_clips_room_today',
      params: {'p_room_id': roomId},
    );

    final photos = (photosRaw as List<dynamic>)
        .map((r) => StudyRoomPhotoSnapRow.fromJson(r as Map<String, dynamic>))
        .toList();
    final clips = (clipsRaw as List<dynamic>)
        .map((r) => StudyRoomVideoClipRow.fromJson(r as Map<String, dynamic>))
        .toList();

    return (photos: photos, clips: clips);
  }
}
