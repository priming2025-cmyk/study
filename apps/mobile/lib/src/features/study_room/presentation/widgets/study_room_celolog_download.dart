import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../domain/celolog_export_speed.dart';
import '../../infra/study_room_celolog_export.dart';

/// 재생 속도 선택 후 [갤러리에 다운로드]로 확정.
Future<CelologExportSpeed?> showCelologDownloadSheet(BuildContext context) {
  return showModalBottomSheet<CelologExportSpeed>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      var selected = CelologExportSpeed.x2;
      return SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '재생 속도',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (final speed in CelologExportSpeed.values) ...[
                        if (speed != CelologExportSpeed.x2)
                          const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: selected == speed
                                  ? Theme.of(ctx).colorScheme.primaryContainer
                                  : null,
                              foregroundColor: selected == speed
                                  ? Theme.of(ctx).colorScheme.onPrimaryContainer
                                  : null,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () =>
                                setLocal(() => selected = speed),
                            child: Text(
                              speed.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(selected),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: Text(kIsWeb ? '다운로드' : '갤러리에 다운로드'),
                  ),
                ],
              ),
            );
          },
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
