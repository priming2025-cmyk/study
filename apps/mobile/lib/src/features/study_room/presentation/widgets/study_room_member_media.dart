import 'package:flutter/material.dart';

import '../../domain/study_room_models.dart';

/// 멤버 카드·뷰어용 공개 미디어 (캡쳐 사진 / 휴식 프로필).
class StudyRoomMemberMedia extends StatelessWidget {
  final StudyRoomMember member;
  final String displayLabel;
  final BoxFit fit;

  const StudyRoomMemberMedia({
    super.key,
    required this.member,
    required this.displayLabel,
    this.fit = BoxFit.cover,
  });

  bool get _isRestMode => member.publicViewerMode == 'rest';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isRestMode) {
      return StudyRoomMemberProfilePlaceholder(
        cs: cs,
        label: displayLabel,
      );
    }

    final snapshotUrl = member.snapshotUrl;
    if (snapshotUrl != null && snapshotUrl.isNotEmpty) {
      return Image.network(
        snapshotUrl,
        fit: fit,
        errorBuilder: (_, __, ___) => StudyRoomMemberMediaPlaceholder(cs: cs),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : StudyRoomMemberMediaPlaceholder(cs: cs),
      );
    }

    return StudyRoomMemberMediaPlaceholder(cs: cs);
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
