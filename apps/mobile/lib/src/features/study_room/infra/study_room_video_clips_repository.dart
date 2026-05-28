import '../../../core/supabase/supabase_client.dart';
import '../domain/study_room_video_clip_row.dart';

abstract final class StudyRoomVideoClipsRepository {
  static Future<List<StudyRoomVideoClipRow>> fetchMyToday({String? roomId}) async {
    try {
      final rows = await supabase.rpc(
        'my_study_room_video_clips_today',
        params: {if (roomId != null) 'p_room_id': roomId},
      );
      if (rows is! List) return const [];
      return rows
          .map((e) => StudyRoomVideoClipRow.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    } catch (e) {
      return const [];
    }
  }
}
