import '../../../core/supabase/supabase_client.dart';
import '../domain/study_room_photo_snap_row.dart';

abstract final class StudyRoomPhotoSnapsRepository {
  static Future<List<StudyRoomPhotoSnapRow>> fetchMyToday({String? roomId}) async {
    try {
      final rows = await supabase.rpc(
        'my_study_room_photo_snaps_today',
        params: {if (roomId != null) 'p_room_id': roomId},
      );
      if (rows is! List) return const [];
      return rows
          .map((e) => StudyRoomPhotoSnapRow.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

