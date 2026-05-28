import 'dart:typed_data';

/// 녹화·압축된 2초 클립 (업로드 전).
class StudyVideoClipResult {
  final Uint8List videoBytes;
  final String mimeType;
  final String fileExtension;
  final int durationMs;
  final Uint8List? posterJpeg;

  const StudyVideoClipResult({
    required this.videoBytes,
    required this.mimeType,
    required this.fileExtension,
    required this.durationMs,
    this.posterJpeg,
  });
}
