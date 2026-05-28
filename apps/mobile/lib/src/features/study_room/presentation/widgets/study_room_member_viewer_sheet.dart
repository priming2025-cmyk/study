import 'package:flutter/material.dart';

import '../../domain/study_room_models.dart';

/// 멤버 카드 우측 모니터 아이콘 → 3가지 뷰어 모드 시트.
enum MemberViewerMode {
  photo, // 1분마다 사진
  video, // 10분마다 2초 영상
  rest,  // 휴식중 (프로필만)
}

class StudyRoomMemberViewerSheet extends StatefulWidget {
  final StudyRoomMember member;

  const StudyRoomMemberViewerSheet({super.key, required this.member});

  static Future<void> show(BuildContext context, {required StudyRoomMember member}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => StudyRoomMemberViewerSheet(member: member),
    );
  }

  @override
  State<StudyRoomMemberViewerSheet> createState() =>
      _StudyRoomMemberViewerSheetState();
}

class _StudyRoomMemberViewerSheetState
    extends State<StudyRoomMemberViewerSheet> {
  MemberViewerMode _mode = MemberViewerMode.photo;

  StudyRoomMember get member => widget.member;

  String get _displayName =>
      member.displayName ?? member.userId.substring(0, 8);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scroll) {
        return Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.secondaryContainer,
                    child: Text(
                      _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayName,
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (member.goalText != null && member.goalText!.isNotEmpty)
                          Text(
                            member.goalText!,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // 집중도 배지
                  _FocusBadge(status: member.status),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // 모드 탭
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<MemberViewerMode>(
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(
                    value: MemberViewerMode.photo,
                    icon: Icon(Icons.camera_alt_outlined, size: 16),
                    label: Text('1분 사진'),
                  ),
                  ButtonSegment(
                    value: MemberViewerMode.video,
                    icon: Icon(Icons.videocam_outlined, size: 16),
                    label: Text('10분 영상'),
                  ),
                  ButtonSegment(
                    value: MemberViewerMode.rest,
                    icon: Icon(Icons.coffee_outlined, size: 16),
                    label: Text('휴식중'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 콘텐츠 영역
            Expanded(
              child: _ModeContent(
                mode: _mode,
                member: member,
                scroll: scroll,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModeContent extends StatelessWidget {
  final MemberViewerMode mode;
  final StudyRoomMember member;
  final ScrollController scroll;

  const _ModeContent({
    required this.mode,
    required this.member,
    required this.scroll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final peerMode = member.publicViewerMode ?? 'capture';
    if (peerMode == 'rest') {
      return SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _RestView(member: member, cs: cs, tt: tt),
      );
    }

    return SingleChildScrollView(
      controller: scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: switch (mode) {
        MemberViewerMode.photo => _PhotoView(member: member),
        MemberViewerMode.video => _VideoView(member: member),
        MemberViewerMode.rest => _RestView(member: member, cs: cs, tt: tt),
      },
    );
  }
}

// ── 1분 사진 뷰 ──────────────────────────────────────────────
class _PhotoView extends StatelessWidget {
  final StudyRoomMember member;

  const _PhotoView({required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final snapshotUrl = member.snapshotUrl;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: snapshotUrl != null
                ? Image.network(snapshotUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _NoSnapshot(cs: cs))
                : _NoSnapshot(cs: cs),
          ),
        ),
        if (member.snapshotAt != null) ...[
          const SizedBox(height: 8),
          Text(
            '마지막 업데이트: ${_formatAgo(member.snapshotAt!)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatAgo(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inSeconds < 60) return '방금 전';
    if (d.inMinutes < 60) return '${d.inMinutes}분 전';
    return '${d.inHours}시간 전';
  }
}

// ── 10분 영상 뷰 ─────────────────────────────────────────────
class _VideoView extends StatelessWidget {
  final StudyRoomMember member;

  const _VideoView({required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final snapshotUrl = member.snapshotUrl;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: snapshotUrl != null
                ? Image.network(snapshotUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _NoSnapshot(cs: cs))
                : _NoSnapshot(cs: cs),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '10분마다 약 2초 구간을 촬영해 올려요',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── 휴식중 뷰 ────────────────────────────────────────────────
class _RestView extends StatelessWidget {
  final StudyRoomMember member;
  final ColorScheme cs;
  final TextTheme tt;

  const _RestView({
    required this.member,
    required this.cs,
    required this.tt,
  });

  String get _displayName =>
      member.displayName ?? member.userId.substring(0, 8);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 260,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: cs.secondaryContainer,
                  child: Text(
                    _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
                    style: tt.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _displayName,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.coffee_outlined,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('휴식 중',
                        style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _NoSnapshot extends StatelessWidget {
  final ColorScheme cs;

  const _NoSnapshot({required this.cs});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.photo_camera_outlined,
          size: 48,
          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _FocusBadge extends StatelessWidget {
  final String? status;

  const _FocusBadge({this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'focus' => ('집중 중', Colors.redAccent),
      'rest' => ('휴식 중', Colors.blueAccent),
      _ => ('대기 중', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
