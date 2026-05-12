class StudyRoom {
  final String id;
  final String ownerUserId;
  final String name;
  final DateTime createdAt;

  const StudyRoom({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.createdAt,
  });

  factory StudyRoom.fromJson(Map<String, dynamic> j) => StudyRoom(
        id: j['id'] as String,
        ownerUserId: j['owner_id'] as String,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class StudyRoomMember {
  final String userId;
  final String? displayName;
  final String? snapshotUrl;
  final DateTime? snapshotAt;
  final String? status; // 'focus' | 'rest' | null
  final String? subjectName;
  final String? goalText;
  final DateTime? joinAt;
  /// 방장만 유효. 다른 멤버는 null.
  final DateTime? timerStartAt;
  final int? timerDurationSecs;
  /// 방장이 일시정지한 경우 true (남은 시간은 [timerPauseRemainingSecs]).
  final bool timerPaused;
  final int? timerPauseRemainingSecs;
  final int? publicLevel;
  final String? publicTitleKo;

  const StudyRoomMember({
    required this.userId,
    this.displayName,
    this.snapshotUrl,
    this.snapshotAt,
    this.status,
    this.subjectName,
    this.goalText,
    this.joinAt,
    this.timerStartAt,
    this.timerDurationSecs,
    this.timerPaused = false,
    this.timerPauseRemainingSecs,
    this.publicLevel,
    this.publicTitleKo,
  });

  bool get isSelf => false;
}

class StudyRoomMessage {
  final String id;
  final String roomId;
  final String userId;
  final String content;
  final DateTime createdAt;

  const StudyRoomMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory StudyRoomMessage.fromJson(Map<String, dynamic> j) => StudyRoomMessage(
        id: j['id'] as String,
        roomId: j['room_id'] as String,
        userId: j['user_id'] as String,
        content: j['content'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class StudyRoomReactionOverlay {
  final String emoji;
  final DateTime receivedAt;

  const StudyRoomReactionOverlay({
    required this.emoji,
    required this.receivedAt,
  });
}
