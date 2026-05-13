import 'package:flutter/material.dart';

import '../../domain/engaged_time_threshold.dart';

/// 집중 초·집중민감도 UI (세션·스터디방 공통).
class EngagedSensitivityMetroCard extends StatelessWidget {
  final int engagedMinScore;
  final Future<void> Function(int value) onSelect;

  const EngagedSensitivityMetroCard({
    super.key,
    required this.engagedMinScore,
    required this.onSelect,
  });

  static const _hints = ['매우 높음', '높음', '보통', '낮음', '매우 낮음'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '집중민감도',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '높음',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 10),
                Text(
                  '낮음',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(kEngagedMinScoreOptions.length, (i) {
                      final step = kEngagedMinScoreOptions[i];
                      final selected = engagedMinScore == step;
                      return Tooltip(
                        message: _hints[i],
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => onSelect(step),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                width: selected ? 22 : 14,
                                height: selected ? 22 : 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected ? cs.primary : cs.surface,
                                  border: Border.all(
                                    color: selected
                                        ? cs.primary
                                        : cs.outline.withAlpha(115),
                                    width: selected ? 0 : 1.5,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: cs.primary.withAlpha(89),
                                            blurRadius: 6,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: selected
                                    ? Center(
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: cs.onPrimary,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
