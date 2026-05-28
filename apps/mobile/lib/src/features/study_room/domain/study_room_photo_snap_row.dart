class StudyRoomPhotoSnapRow {
  final String id;
  final String roomId;
  final String userId;
  final String storagePath;
  final String publicUrl;
  final int? sizeBytes;
  final DateTime recordedAt;
  final DateTime expiresAt;
  /// 사진 촬영 시점의 공부 상태 텍스트 (셀로그 오버레이용)
  final String? statusText;

  const StudyRoomPhotoSnapRow({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.storagePath,
    required this.publicUrl,
    this.sizeBytes,
    required this.recordedAt,
    required this.expiresAt,
    this.statusText,
  });

  factory StudyRoomPhotoSnapRow.fromJson(Map<String, dynamic> j) =>
      StudyRoomPhotoSnapRow(
        id: j['id'] as String,
        roomId: j['room_id'] as String,
        userId: j['user_id'] as String,
        storagePath: j['storage_path'] as String,
        publicUrl: j['public_url'] as String,
        sizeBytes: (j['size_bytes'] as num?)?.toInt(),
        recordedAt: DateTime.parse(j['recorded_at'] as String),
        expiresAt: DateTime.parse(j['expires_at'] as String),
        statusText: j['status_text'] as String?,
      );
}

