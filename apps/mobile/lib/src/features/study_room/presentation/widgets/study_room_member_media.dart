import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/study_room_focus_timeline.dart';
import '../../domain/study_room_models.dart';
import '../../infra/study_room_controller.dart';
import 'study_room_focus_trend_overlay.dart';

/// 멤버 카드·뷰어용 공개 미디어 (캡쳐 사진 / 휴식 프로필 + 집중 흐름).
class StudyRoomMemberMedia extends StatefulWidget {
  final StudyRoomMember member;
  final String displayLabel;
  final BoxFit fit;
  final StudyRoomController? controller;

  const StudyRoomMemberMedia({
    super.key,
    required this.member,
    required this.displayLabel,
    this.fit = BoxFit.cover,
    this.controller,
  });

  @override
  State<StudyRoomMemberMedia> createState() => _StudyRoomMemberMediaState();
}

class _StudyRoomMemberMediaState extends State<StudyRoomMemberMedia> {
  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    if (c != null && widget.member.publicViewerMode == 'rest') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(c.refreshRoomFocusSnapshots());
      });
    }
  }

  bool get _isRestMode => widget.member.publicViewerMode == 'rest';

  List<int> get _trendScores {
    final c = widget.controller;
    if (c != null) {
      return c.focusTrendScoresFor(
        widget.member.userId,
        fallbackScore: widget.member.focusScore,
      );
    }
    final fb = widget.member.focusScore;
    return fb != null && fb > 0 ? [fb] : const [];
  }

  String? get _trendSubtitle {
    final scores = _trendScores;
    if (scores.length < StudyRoomFocusTimeline.minPointsForChart) return null;
    final c = widget.controller;
    if (c != null && widget.member.userId == c.selfId) return '실시간';
    return '오늘 ${scores.length}분';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scores = _trendScores;

    if (_isRestMode) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _restProfileBackground(cs),
          if (scores.isNotEmpty)
            Positioned.fill(
              child: StudyRoomFocusTrendOverlay(
                scores: scores,
                headlineScore: widget.member.focusScore ??
                    StudyRoomFocusTimeline.averageOf(scores),
                subtitle: _trendSubtitle,
              ),
            ),
        ],
      );
    }

    final snapshotUrl = widget.member.snapshotUrl;
    if (snapshotUrl != null && snapshotUrl.isNotEmpty) {
      return Image.network(
        snapshotUrl,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => StudyRoomMemberMediaPlaceholder(cs: cs),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : StudyRoomMemberMediaPlaceholder(cs: cs),
      );
    }

    return StudyRoomMemberMediaPlaceholder(cs: cs);
  }

  Widget _restProfileBackground(ColorScheme cs) {
    final url = widget.member.snapshotUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: widget.fit,
        errorBuilder: (_, __, ___) =>
            StudyRoomMemberProfilePlaceholder(cs: cs, label: widget.displayLabel),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : StudyRoomMemberProfilePlaceholder(cs: cs, label: widget.displayLabel),
      );
    }
    return StudyRoomMemberProfilePlaceholder(
      cs: cs,
      label: widget.displayLabel,
    );
  }
}

class StudyRoomMemberMediaPlaceholder extends StatelessWidget {
  final ColorScheme cs;

  const StudyRoomMemberMediaPlaceholder({super.key, required this.cs});

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

class StudyRoomMemberProfilePlaceholder extends StatelessWidget {
  final ColorScheme cs;
  final String label;

  const StudyRoomMemberProfilePlaceholder({
    super.key,
    required this.cs,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: cs.primaryContainer,
              child: Text(
                label.isNotEmpty ? label.substring(0, 1) : '?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
