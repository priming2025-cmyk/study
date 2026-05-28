class StudyRoomVideoClipRow {
  final String id;
  final String roomId;
  final String userId;
  final String storagePath;
  final String publicUrl;
  final String? posterUrl;
  final String mimeType;
  final int? durationMs;
  final int? sizeBytes;
  final DateTime recordedAt;
  final DateTime expiresAt;

  const StudyRoomVideoClipRow({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.storagePath,
    required this.publicUrl,
    this.posterUrl,
    required this.mimeType,
    this.durationMs,
    this.sizeBytes,
    required this.recordedAt,
    required this.expiresAt,
  });

  factory StudyRoomVideoClipRow.fromJson(Map<String, dynamic> j) =>
      StudyRoomVideoClipRow(
        id: j['id'] as String,
        roomId: j['room_id'] as String,
        userId: j['user_id'] as String,
        storagePath: j['storage_path'] as String,
        publicUrl: j['public_url'] as String,
        posterUrl: j['poster_url'] as String?,
        mimeType: (j['mime_type'] as String?) ?? 'video/mp4',
        durationMs: (j['duration_ms'] as num?)?.toInt(),
        sizeBytes: (j['size_bytes'] as num?)?.toInt(),
        recordedAt: DateTime.parse(j['recorded_at'] as String),
        expiresAt: DateTime.parse(j['expires_at'] as String),
      );
}
