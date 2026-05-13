import 'package:shared_preferences/shared_preferences.dart';

const _prefKeyRecentStudyRoomId = 'recent_study_room_id_v1';
const _prefKeyRecentStudyRoomGoal = 'recent_study_room_goal_v1';

Future<void> saveRecentStudyRoom({
  required String roomId,
  required String goalText,
}) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(_prefKeyRecentStudyRoomId, roomId);
  await sp.setString(_prefKeyRecentStudyRoomGoal, goalText);
}

Future<(String roomId, String goalText)?> loadRecentStudyRoom() async {
  final sp = await SharedPreferences.getInstance();
  final id = sp.getString(_prefKeyRecentStudyRoomId);
  if (id == null || id.trim().isEmpty) return null;
  final goal = sp.getString(_prefKeyRecentStudyRoomGoal) ?? '';
  return (id.trim(), goal.trim());
}

