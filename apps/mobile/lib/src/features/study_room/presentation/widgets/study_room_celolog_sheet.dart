import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/study_room_photo_snap_row.dart';
import '../../domain/study_room_video_clip_row.dart';
import '../../infra/study_room_controller.dart';
import '../../infra/study_room_celolog_repository.dart';
import '../../infra/study_room_photo_snaps_repository.dart';
import '../../infra/study_room_video_clips_repository.dart';
import '../../infra/setlog_grid_timelapse_builder.dart';

Future<void> showStudyRoomCelologSheet(
  BuildContext context, {
  required String? roomId,
  required StudyRoomController controller,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _CelologBody(roomId: roomId, controller: controller),
  );
}

class _CelologBody extends StatefulWidget {
  final String? roomId;
  final StudyRoomController controller;

  const _CelologBody({this.roomId, required this.controller});

  @override
  State<_CelologBody> createState() => _CelologBodyState();
}

class _CelologBodyState extends State<_CelologBody> {
  late Future<_CelologData> _future;
  bool _buildingVideo = false;
  String? _successMsg;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _loadData();
  }

  Future<_CelologData> _loadData() async {
    final rid = widget.roomId;
    if (rid == null) {
      // 방 정보 없으면 내 것만
      final myClips = await StudyRoomVideoClipsRepository.fetchMyToday(
          roomId: null);
      final myPhotos =
          await StudyRoomPhotoSnapsRepository.fetchMyToday(roomId: null);
      return _CelologData(
        clips: myClips,
        photoCount: myPhotos.length,
        memberCount: 1,
      );
    }

    // 방 전체 멤버 데이터
    final roomData = await StudyRoomCelologRepository.fetchRoomToday(
        roomId: rid);
    final slots = _resolveGridSlots(
      controllerSlots: widget.controller.celologMemberSlots,
      photos: roomData.photos,
      clips: roomData.clips,
    );
    return _CelologData(
      clips: roomData.clips,
      photoCount: roomData.photos.length,
      memberCount: slots.length,
      allPhotos: roomData.photos,
      allClips: roomData.clips,
      gridSlots: slots,
    );
  }

  /// Presence에 아직 없는 멤버도 사진/클립 데이터 기준으로 슬롯에 포함
  List<GridMemberSlot> _resolveGridSlots({
    required List<({String userId, String? displayName, String? statusText})>
        controllerSlots,
    required List<StudyRoomPhotoSnapRow> photos,
    required List<StudyRoomVideoClipRow> clips,
  }) {
    final slotByUser = <String, GridMemberSlot>{};

    void put(String userId, {String? displayName, String? statusText}) {
      slotByUser[userId] = GridMemberSlot(
        userId: userId,
        displayName: displayName ?? widget.controller.displayNameFor(userId),
        statusText: statusText,
      );
    }

    for (final s in controllerSlots) {
      put(s.userId, displayName: s.displayName, statusText: s.statusText);
    }

    for (final p in photos) {
      slotByUser.putIfAbsent(
        p.userId,
        () => GridMemberSlot(
          userId: p.userId,
          displayName: widget.controller.displayNameFor(p.userId),
          statusText: p.statusText,
        ),
      );
    }
    for (final c in clips) {
      slotByUser.putIfAbsent(
        c.userId,
        () => GridMemberSlot(
          userId: c.userId,
          displayName: widget.controller.displayNameFor(c.userId),
        ),
      );
    }

    final selfId = widget.controller.selfId;
    final ordered = <GridMemberSlot>[];
    if (selfId != null) {
      final self = slotByUser.remove(selfId);
      if (self != null) ordered.add(self);
    }
    for (final s in controllerSlots) {
      if (s.userId == selfId) continue;
      final slot = slotByUser.remove(s.userId);
      if (slot != null) ordered.add(slot);
    }
    ordered.addAll(slotByUser.values);
    return ordered;
  }

  Future<void> _buildGridVideo() async {
    if (_buildingVideo) return;
    setState(() {
      _buildingVideo = true;
      _successMsg = null;
    });

    try {
      final data = await _future;
      final slots = data.gridSlots.isNotEmpty
          ? data.gridSlots
          : _resolveGridSlots(
              controllerSlots: widget.controller.celologMemberSlots,
              photos: data.allPhotos,
              clips: data.allClips,
            );

      final result = await SetlogGridTimelapseBuilder.buildAndSave(
        input: GridBuildInput(
          slots: slots,
          allPhotos: data.allPhotos,
          allClips: data.allClips,
          downloadedAt: DateTime.now(),
        ),
      );

      if (!mounted) return;
      if (result != null) {
        setState(() => _successMsg = '갤러리에 저장됐어요 🎉');
      }
      // 결과 없어도 조용히 처리 (데이터 없음)
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
              '24시간 동안만 보관돼요. 함께 공부한 모든 멤버의 사진·영상을 1시간=4초로 합칩니다.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FutureBuilder<_CelologData>(
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
                final data = snap.data!;
                final clips = data.clips;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 통계
                    Row(
                      children: [
                        _statChip(
                          icon: Icons.group_outlined,
                          label: '${data.memberCount}명',
                          cs: cs,
                        ),
                        const SizedBox(width: 8),
                        _statChip(
                          icon: Icons.photo_outlined,
                          label: '사진 ${data.photoCount}장',
                          cs: cs,
                        ),
                        const SizedBox(width: 8),
                        _statChip(
                          icon: Icons.movie_outlined,
                          label: '영상 ${clips.length}개',
                          cs: cs,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 시간 범위 표시
                    if (data.photoCount > 0 || clips.isNotEmpty)
                      _buildHourChips(data, tt, cs),
                    const SizedBox(height: 14),

                    // 성공 메시지
                    if (_successMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _successMsg!,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // 갤러리 저장 버튼
                    FilledButton.icon(
                      onPressed: _buildingVideo ? null : _buildGridVideo,
                      icon: _buildingVideo
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.video_library_rounded),
                      label: Text(
                        _buildingVideo
                            ? '영상 만드는 중… (잠시 기다려 주세요)'
                            : kIsWeb
                                ? '셀로그 영상 다운로드 (WebM)'
                                : '셀로그 영상 갤러리에 저장',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '3배속 · 1시간 = 약 4초 · 멤버 그리드 영상',
                      style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant, fontSize: 11),
                      textAlign: TextAlign.center,
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

  Widget _statChip({
    required IconData icon,
    required String label,
    required ColorScheme cs,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourChips(
    _CelologData data,
    TextTheme tt,
    ColorScheme cs,
  ) {
    // 사진/영상의 시간대를 수집해 표시
    final hours = <int>{};
    for (final p in data.allPhotos) {
      hours.add(p.recordedAt.toLocal().hour);
    }
    for (final c in data.allClips) {
      hours.add(c.recordedAt.toLocal().hour);
    }
    if (hours.isEmpty) return const SizedBox.shrink();

    final sorted = hours.toList()..sort();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: sorted
          .map((h) => Chip(
                padding: EdgeInsets.zero,
                label: Text('${h.toString().padLeft(2, '0')}:00',
                    style: const TextStyle(fontSize: 11)),
                backgroundColor: cs.secondaryContainer,
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 8),
              ))
          .toList(),
    );
  }
}

class _CelologData {
  final List<StudyRoomVideoClipRow> clips;
  final int photoCount;
  final int memberCount;
  final List<StudyRoomPhotoSnapRow> allPhotos;
  final List<StudyRoomVideoClipRow> allClips;
  final List<GridMemberSlot> gridSlots;

  _CelologData({
    required this.clips,
    required this.photoCount,
    required this.memberCount,
    this.allPhotos = const [],
    this.allClips = const [],
    this.gridSlots = const [],
  });
}
