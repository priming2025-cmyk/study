import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _prefKeyRecentRooms = 'recent_study_rooms_v2';
const _maxRecentRooms = 10;

/// 최근 접속한 셋 정보 모델.
class RecentStudyRoom {
  final String roomId;
  final String joinCode;
  final String goalText;
  final List<String> participantNames;
  final DateTime lastAccessedAt;

  const RecentStudyRoom({
    required this.roomId,
    this.joinCode = '',
    required this.goalText,
    this.participantNames = const [],
    required this.lastAccessedAt,
  });

  /// 카드·공유에 쓸 짧은 입장코드 (없으면 roomId 앞 6자).
  String get displayCode {
    if (joinCode.isNotEmpty) return joinCode;
    final compact = roomId.replaceAll('-', '');
    if (compact.length >= 6) return compact.substring(0, 6).toUpperCase();
    return compact.toUpperCase();
  }

  /// 참석자 표시 — 3명 이하면 전원, 초과 시 「이름 외 N명」.
  String get participantsLabel => formatParticipantNames(participantNames);

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'joinCode': joinCode,
        'goalText': goalText,
        'participantNames': participantNames,
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
      };

  factory RecentStudyRoom.fromJson(Map<String, dynamic> json) {
    final rawNames = json['participantNames'];
    List<String> names = const [];
    if (rawNames is List) {
      names = rawNames.map((e) => e.toString()).where((n) => n.isNotEmpty).toList();
    }
    return RecentStudyRoom(
      roomId: json['roomId'] as String,
      joinCode: json['joinCode'] as String? ?? '',
      goalText: json['goalText'] as String? ?? '',
      participantNames: names,
      lastAccessedAt:
          DateTime.tryParse(json['lastAccessedAt'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  String get lastAccessedLabel {
    final diff = DateTime.now().difference(lastAccessedAt);
    if (diff.inMinutes < 2) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

/// 참석자 이름 목록을 카드용 한 줄 문자열로 변환.
String formatParticipantNames(List<String> names) {
  final filtered = names.map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
  if (filtered.isEmpty) return '참석자 없음';
  if (filtered.length <= 3) return filtered.join(', ');
  return '${filtered.first} 외 ${filtered.length - 1}명';
}

Future<void> saveRecentStudyRoom({
  required String roomId,
  String joinCode = '',
  required String goalText,
  List<String> participantNames = const [],
}) async {
  final sp = await SharedPreferences.getInstance();
  final rooms = await loadRecentStudyRooms();
  final filtered = rooms.where((r) => r.roomId != roomId).toList();
  final updated = [
    RecentStudyRoom(
      roomId: roomId,
      joinCode: joinCode,
      goalText: goalText,
      participantNames: participantNames,
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
