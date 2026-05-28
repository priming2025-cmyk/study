import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/study_video_clip_result.dart';

const _bucket = 'study-snapshots';

class StudyVideoClipUploadResult {
  final String storagePath;
  final String publicUrl;
  final String? posterUrl;
  final int sizeBytes;
  final String mimeType;

  const StudyVideoClipUploadResult({
    required this.storagePath,
    required this.publicUrl,
    this.posterUrl,
    required this.sizeBytes,
    required this.mimeType,
  });
}

abstract final class StudyVideoClipUploader {
  static Future<StudyVideoClipUploadResult?> upload({
    required String roomId,
    required String userId,
    required StudyVideoClipResult clip,
  }) async {
    if (clip.videoBytes.isEmpty) return null;
    if (clip.videoBytes.length > 512 * 1024) return null;

    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    final ext = clip.fileExtension;
    final storagePath = 'clips/$roomId/$userId/$ts.$ext';

    try {
      await supabase.storage.from(_bucket).uploadBinary(
            storagePath,
            clip.videoBytes,
            fileOptions: FileOptions(
              contentType: clip.mimeType,
              upsert: false,
            ),
          );

      String? posterUrl;
      final poster = clip.posterJpeg;
      if (poster != null && poster.isNotEmpty) {
        final posterPath = 'clips/$roomId/$userId/${ts}_poster.jpg';
        await supabase.storage.from(_bucket).uploadBinary(
              posterPath,
              poster,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        posterUrl = supabase.storage.from(_bucket).getPublicUrl(posterPath);
      }

      final base = supabase.storage.from(_bucket).getPublicUrl(storagePath);
      final publicUrl = '$base?t=$ts';

      return StudyVideoClipUploadResult(
        storagePath: storagePath,
        publicUrl: publicUrl,
        posterUrl: posterUrl,
        sizeBytes: clip.videoBytes.length,
        mimeType: clip.mimeType,
      );
    } catch (e) {
      return null;
    }
  }
}
