import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _prefKeyRecentRooms = 'recent_study_rooms_v2';
const _maxRecentRooms = 10;

/// 최근 접속한 셋 정보 모델.
class RecentStudyRoom {
  final String roomId;
  final String joinCode;
  final String roomName;
  final int maxPeers;
  final String goalText;
  final List<String> participantNames;
  final DateTime lastAccessedAt;
  /// 방 내부에서 마지막으로 활동이 있었던 시각(최근 메시지 기준 등).
  final DateTime lastActivityAt;

  const RecentStudyRoom({
    required this.roomId,
    this.joinCode = '',
    this.roomName = '',
    this.maxPeers = 8,
    required this.goalText,
    this.participantNames = const [],
    required this.lastAccessedAt,
    required this.lastActivityAt,
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
        'roomName': roomName,
        'maxPeers': maxPeers,
        'goalText': goalText,
        'participantNames': participantNames,
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
        'lastActivityAt': lastActivityAt.toIso8601String(),
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
      roomName: json['roomName'] as String? ?? '',
      maxPeers: (json['maxPeers'] as int?)?.clamp(2, 8) ?? 8,
      goalText: json['goalText'] as String? ?? '',
      participantNames: names,
      lastAccessedAt:
          DateTime.tryParse(json['lastAccessedAt'] as String? ?? '') ??
              DateTime.now(),
      lastActivityAt: DateTime.tryParse(
            json['lastActivityAt'] as String? ?? '',
          ) ??
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

  String get lastActivityLabel {
    final diff = DateTime.now().difference(lastActivityAt);
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

/// 최근 셋 카드용 참석자 표시.
///
/// - 기본: 한 줄에 3명 정도 들어가도록 줄바꿈
/// - 최대 2줄까지만 보여주고, 넘치면 `...`(TextOverflow.ellipsis)로 잘립니다.
String formatParticipantNamesTwoLines(
  List<String> names, {
  int perLine = 3,
  int maxLines = 2,
  String separator = ' · ',
}) {
  final filtered =
      names.map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
  if (filtered.isEmpty) return '참석자 없음';

  final maxVisible = perLine * maxLines;
  final visible = filtered.take(maxVisible).toList();
  final truncated = filtered.length > maxVisible;

  final lines = <String>[];
  for (var i = 0; i < visible.length; i += perLine) {
    final line = visible.skip(i).take(perLine).join(separator);
    final isLastGeneratedLine = i + perLine >= visible.length;
    if (truncated && isLastGeneratedLine) {
      lines.add('$line...');
    } else {
      lines.add(line);
    }
  }
  return lines.join('\n');
}

Future<void> saveRecentStudyRoom({
  required String roomId,
  String joinCode = '',
  String roomName = '',
  int maxPeers = 8,
  required String goalText,
  List<String> participantNames = const [],
  DateTime? lastActivityAt,
}) async {
  final sp = await SharedPreferences.getInstance();
  final rooms = await loadRecentStudyRooms();
  final filtered = rooms.where((r) => r.roomId != roomId).toList();
  final myLastAccessAt = DateTime.now();
  final activityAt = lastActivityAt ?? myLastAccessAt;
  final updated = [
    RecentStudyRoom(
      roomId: roomId,
      joinCode: joinCode,
      roomName: roomName,
      maxPeers: maxPeers,
      goalText: goalText,
      participantNames: participantNames,
      lastAccessedAt: myLastAccessAt,
      lastActivityAt: activityAt,
    ),
    ...filtered,
  ];
  updated.sort((a, b) {
    final activityCmp = b.lastActivityAt.compareTo(a.lastActivityAt);
    if (activityCmp != 0) return activityCmp;
    return b.lastAccessedAt.compareTo(a.lastAccessedAt);
  });
  final trimmed = updated.take(_maxRecentRooms).toList();

  await sp.setString(
    _prefKeyRecentRooms,
    jsonEncode(trimmed.map((r) => r.toJson()).toList()),
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
          lastActivityAt: DateTime.now(),
        ),
      ];
    }
    return const [];
  }
  try {
    final list = jsonDecode(json) as List;
    final parsed = list
        .map((e) => RecentStudyRoom.fromJson(e as Map<String, dynamic>))
        .toList();
    parsed.sort((a, b) {
      final activityCmp = b.lastActivityAt.compareTo(a.lastActivityAt);
      if (activityCmp != 0) return activityCmp;
      return b.lastAccessedAt.compareTo(a.lastAccessedAt);
    });
    return parsed;
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

/// 방 안에서 새 메시지 등 활동이 생겼을 때 최근 셋의 [lastActivityAt]을 갱신합니다.
Future<bool> touchRecentStudyRoomActivity({
  required String roomId,
  DateTime? activityAt,
}) async {
  final sp = await SharedPreferences.getInstance();
  final json = sp.getString(_prefKeyRecentRooms);
  if (json == null || json.isEmpty) return false;

  List<RecentStudyRoom> rooms;
  try {
    final list = jsonDecode(json) as List;
    rooms = list
        .map((e) => RecentStudyRoom.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return false;
  }

  final idx = rooms.indexWhere((r) => r.roomId == roomId);
  if (idx < 0) return false;

  final at = activityAt ?? DateTime.now();
  final old = rooms[idx];
  rooms[idx] = RecentStudyRoom(
    roomId: old.roomId,
    joinCode: old.joinCode,
    roomName: old.roomName,
    maxPeers: old.maxPeers,
    goalText: old.goalText,
    participantNames: old.participantNames,
    lastAccessedAt: old.lastAccessedAt,
    lastActivityAt: at,
  );

  rooms.sort((a, b) {
    final activityCmp = b.lastActivityAt.compareTo(a.lastActivityAt);
    if (activityCmp != 0) return activityCmp;
    return b.lastAccessedAt.compareTo(a.lastAccessedAt);
  });

  await sp.setString(
    _prefKeyRecentRooms,
    jsonEncode(rooms.take(_maxRecentRooms).map((r) => r.toJson()).toList()),
  );
  return true;
}
