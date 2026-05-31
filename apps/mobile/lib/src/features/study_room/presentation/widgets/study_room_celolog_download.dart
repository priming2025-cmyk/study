import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../domain/celolog_export_speed.dart';
import '../../infra/study_room_celolog_export.dart';

/// 셀로그 다운로드 전 재생 속도 선택.
Future<CelologExportSpeed?> showCelologSpeedPicker(BuildContext context) {
  return showModalBottomSheet<CelologExportSpeed>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '재생 속도',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'x2: 1초에 6장 · x4: 12장 · x10: 30장',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final speed in CelologExportSpeed.values)
                    FilledButton.tonal(
                      onPressed: () => Navigator.of(ctx).pop(speed),
                      child: Text(speed.label),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

String celologExportResultMessage(CelologExportResult result) {
  return switch (result) {
    CelologExportResult.success =>
      kIsWeb ? '다운로드가 시작됐어요' : '갤러리에 저장됐어요',
    CelologExportResult.noData =>
      '오늘 저장된 캡쳐 사진이 없어요. 친구와 함께 공부한 뒤 다시 시도해 주세요.',
    CelologExportResult.failed => '셀로그 영상을 만들지 못했어요',
  };
}

String celologExportProgressMessage() =>
    kIsWeb ? '셀로그 영상 다운로드 중…' : '갤러리에 저장하는 중…';
