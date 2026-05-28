import 'package:flutter/material.dart';

import '../../domain/study_room_video_clip_row.dart';
import '../../infra/celolog_download_service.dart';
import '../../infra/study_room_video_clips_repository.dart';
import '../../infra/study_room_photo_snaps_repository.dart';
import '../../infra/setlog_timelapse_builder.dart';

Future<void> showStudyRoomCelologSheet(
  BuildContext context, {
  required String? roomId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _CelologBody(roomId: roomId),
  );
}

class _CelologBody extends StatefulWidget {
  final String? roomId;

  const _CelologBody({this.roomId});

  @override
  State<_CelologBody> createState() => _CelologBodyState();
}

class _CelologBodyState extends State<_CelologBody> {
  late Future<List<StudyRoomVideoClipRow>> _future;
  bool _downloading = false;
  bool _buildingVideo = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = StudyRoomVideoClipsRepository.fetchMyToday(roomId: widget.roomId);
  }

  Future<void> _download(List<StudyRoomVideoClipRow> clips) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final err = await CelologDownloadService.buildAndShareZip(clips: clips);
    if (!mounted) return;
    setState(() => _downloading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _buildSetlogVideo(List<StudyRoomVideoClipRow> clips) async {
    if (_buildingVideo) return;
    setState(() => _buildingVideo = true);
    try {
      final photos =
          await StudyRoomPhotoSnapsRepository.fetchMyToday(roomId: widget.roomId);
      final err = await SetlogTimelapseBuilder.buildAndShare(
        input: SetlogBuildInput(
          photos: photos,
          clips: clips,
          downloadedAt: DateTime.now(),
          fps: 10, // 3배속: 1분=0.1초
        ),
      );
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    } finally {
      if (mounted) setState(() => _buildingVideo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '오늘 셀로그',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '24시간 동안만 보관돼요. ZIP으로 받으면 시간순 클립이 들어 있어요.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<StudyRoomVideoClipRow>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Text('불러오기 실패: ${snap.error}');
                }
                final clips = snap.data ?? const [];
                if (clips.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      '아직 오늘 올린 2초 영상이 없어요.\n2초 영상 모드를 켜고 방에 머물러 주세요.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                final totalKb = clips.fold<int>(
                  0,
                  (a, c) => a + (c.sizeBytes ?? 0),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${clips.length}개 클립 · 약 ${(totalKb / 1024).toStringAsFixed(0)} KB',
                      style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.35,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: clips.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final c = clips[i];
                          final t = c.recordedAt.toLocal();
                          final time =
                              '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
                          final kb = ((c.sizeBytes ?? 0) / 1024).toStringAsFixed(0);
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.movie_outlined),
                            title: Text('$time · ${c.mimeType.contains('webm') ? 'WebM' : 'MP4'}'),
                            subtitle: Text('$kb KB · 자정에 삭제'),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _downloading ? null : () => _download(clips),
                      icon: _downloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(_downloading ? '만드는 중…' : '셀로그 ZIP 다운로드'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _buildingVideo ? null : () => _buildSetlogVideo(clips),
                      icon: _buildingVideo
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.movie_creation_outlined),
                      label: Text(_buildingVideo ? '공부 끝! 만드는 중…' : '공부 끝! 영상 만들기 (3배속)'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
