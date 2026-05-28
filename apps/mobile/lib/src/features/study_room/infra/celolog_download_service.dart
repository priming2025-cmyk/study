import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../domain/study_room_video_clip_row.dart';

/// 오늘 클립을 ZIP(셀로그)으로 묶어 공유. (원본 클립 그대로 — 서버 재인코딩 없음)
abstract final class CelologDownloadService {
  static Future<String?> buildAndShareZip({
    required List<StudyRoomVideoClipRow> clips,
  }) async {
    if (clips.isEmpty) return '오늘 올라간 클립이 없어요';

    final archive = Archive();
    var index = 0;
    for (final c in clips) {
      index++;
      try {
        final res = await http.get(Uri.parse(c.publicUrl));
        if (res.statusCode != 200 || res.bodyBytes.isEmpty) continue;
        final ext = c.mimeType.contains('webm') ? 'webm' : 'mp4';
        final local = c.recordedAt.toLocal();
        final name =
            '${index.toString().padLeft(3, '0')}_'
            '${local.hour}${local.minute.toString().padLeft(2, '0')}'
            '${local.second.toString().padLeft(2, '0')}.$ext';
        archive.addFile(ArchiveFile(name, res.bodyBytes.length, res.bodyBytes));
      } catch (e) {
        debugPrint('[CelologDownload] fetch ${c.id}: $e');
      }
    }

    if (archive.files.isEmpty) {
      return '클립을 불러오지 못했어요';
    }

    final zipped = ZipEncoder().encode(archive);
    if (zipped.isEmpty) {
      return '압축에 실패했어요';
    }
    final zipBytes = Uint8List.fromList(zipped);
    final day = clips.first.recordedAt.toLocal();
    final label =
        'setudy_celolog_${day.year}'
        '${day.month.toString().padLeft(2, '0')}'
        '${day.day.toString().padLeft(2, '0')}.zip';

    await Share.shareXFiles(
      [XFile.fromData(zipBytes, name: label, mimeType: 'application/zip')],
      text: '셋터디 셀로그 (오늘 ${archive.files.length}개 클립)',
    );
    return null;
  }
}
