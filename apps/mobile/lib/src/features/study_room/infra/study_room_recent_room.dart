import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _prefKeyRecentRooms = 'recent_study_rooms_v2';
const _maxRecentRooms = 10;

/// 최근 접속한 셋 정보 모델.
class RecentStudyRoom {
  final String roomId;
  final String roomName;
  final String goalText;
  final DateTime lastAccessedAt;

  const RecentStudyRoom({
    required this.roomId,
    required this.roomName,
    required this.goalText,
    required this.lastAccessedAt,
  });

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'roomName': roomName,
        'goalText': goalText,
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
      };

  factory RecentStudyRoom.fromJson(Map<String, dynamic> json) =>
      RecentStudyRoom(
        roomId: json['roomId'] as String,
        roomName: json['roomName'] as String? ?? '셋터디방',
        goalText: json['goalText'] as String? ?? '',
        lastAccessedAt:
            DateTime.tryParse(json['lastAccessedAt'] as String? ?? '') ??
                DateTime.now(),
      );

  String get lastAccessedLabel {
    final diff = DateTime.now().difference(lastAccessedAt);
    if (diff.inMinutes < 2) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

Future<void> saveRecentStudyRoom({
  required String roomId,
  required String goalText,
  String roomName = '셋터디방',
}) async {
  final sp = await SharedPreferences.getInstance();
  final rooms = await loadRecentStudyRooms();
  final filtered = rooms.where((r) => r.roomId != roomId).toList();
  final updated = [
    RecentStudyRoom(
      roomId: roomId,
      roomName: roomName,
      goalText: goalText,
      lastAccessedAt: DateTime.now(),
    ),
    ...filtered,
  ].take(_maxRecentRooms).toList();

  await sp.setString(
    _prefKeyRecentRooms,
    jsonEncode(updated.map((r) => r.toJson()).toList()),
  );
  // 하위호환: 기존 단일 키도 유지
  await sp.setString('recent_study_room_id_v1', roomId);
  await sp.setString('recent_study_room_goal_v1', goalText);
}

Future<List<RecentStudyRoom>> loadRecentStudyRooms() async {
  final sp = await SharedPreferences.getInstance();
  final json = sp.getString(_prefKeyRecentRooms);
  if (json == null || json.isEmpty) {
    // 기존 단일 항목 마이그레이션
    final oldId = sp.getString('recent_study_room_id_v1');
    if (oldId != null && oldId.isNotEmpty) {
      final goal = sp.getString('recent_study_room_goal_v1') ?? '';
      return [
        RecentStudyRoom(
          roomId: oldId,
          roomName: '최근 셋',
          goalText: goal,
          lastAccessedAt: DateTime.now(),
        ),
      ];
    }
    return const [];
  }
  try {
    final list = jsonDecode(json) as List;
    return list
        .map((e) => RecentStudyRoom.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return const [];
  }
}

/// 하위호환 - 가장 최근 셋 하나 반환.
Future<(String roomId, String goalText)?> loadRecentStudyRoom() async {
  final rooms = await loadRecentStudyRooms();
  if (rooms.isEmpty) return null;
  return (rooms.first.roomId, rooms.first.goalText);
}
