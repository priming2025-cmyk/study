class StudyRoomPhotoSnapRow {
  final String id;
  final String roomId;
  final String userId;
  final String storagePath;
  final String publicUrl;
  final int? sizeBytes;
  final DateTime recordedAt;
  final DateTime expiresAt;

  const StudyRoomPhotoSnapRow({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.storagePath,
    required this.publicUrl,
    this.sizeBytes,
    required this.recordedAt,
    required this.expiresAt,
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
      );
}

