import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<void> showPremiumVideoSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.paddingOf(sheetContext).bottom + 20,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '영상 스터디방',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'P2P 영상은 네트워크·TURN 비용이 들어가요. 무료로는 집중 세션에서 '
              '실시간 출석(같이 공부 중)을 먼저 쓰시고, 원하시면 프리미엄에서 영상방을 열 수 있어요.',
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                GoRouter.of(context).go('/session');
              },
              icon: const Icon(Icons.timer_outlined),
              label: const Text('무료 집중 세션으로 이동'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('닫기'),
            ),
            const SizedBox(height: 8),
            Text(
              '개발 테스트: apps/mobile/.env 에 PREMIUM_VIDEO_ENABLED=true 설정 시 잠금 해제',
              style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    },
  );
}
