import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_picker_row.dart';
import 'engaged_sensitivity_metro_card.dart';

/// 집중·셋터디 공통 설정 시트 (집중민감도 + 색 테마).
class SessionSettingsSheet extends StatelessWidget {
  const SessionSettingsSheet({
    super.key,
    required this.engagedMinScore,
    required this.onSelectSensitivity,
  });

  final int engagedMinScore;
  final Future<void> Function(int value) onSelectSensitivity;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EngagedSensitivityMetroCard(
              engagedMinScore: engagedMinScore,
              onSelect: onSelectSensitivity,
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: AppThemePickerRow(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
