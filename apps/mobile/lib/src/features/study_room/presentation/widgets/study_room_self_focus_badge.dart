import 'package:flutter/material.dart';

import '../../../session/domain/attention_scoring.dart';

/// 스터디방 본인 실시간 프리뷰 위 집중 점수·상태 뱃지.
class StudyRoomSelfFocusBadge extends StatelessWidget {
  final int score;
  final FocusStatus status;

  const StudyRoomSelfFocusBadge({
    super.key,
    required this.score,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      left: 8,
      top: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                status.label,
                style: TextStyle(color: cs.primaryContainer, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
