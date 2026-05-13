import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/shell_branch_index_provider.dart';

enum _LeaveSessionChoice { saveAndLeave, cancel }

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(shellBranchIndexProvider.notifier).state =
          widget.navigationShell.currentIndex;
    });
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex != widget.navigationShell.currentIndex) {
      ref.read(shellBranchIndexProvider.notifier).state =
          widget.navigationShell.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) async {
          final currentIndex = widget.navigationShell.currentIndex;
          // 공부 탭에서 다른 탭으로 이동할 때 세션이 실행 중이면 확인 다이얼로그 표시
          if (currentIndex == kShellBranchSession &&
              index != kShellBranchSession &&
              ref.read(sessionRunningProvider)) {
            final choice = await showDialog<_LeaveSessionChoice>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('공부 중이에요'),
                content: const Text(
                  '카메라가 켜진 채로 다른 탭으로 이동할 수 없어요.\n'
                  '지금까지의 집중 기록을 자동 저장하고 카메라를 끄시겠어요?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(_LeaveSessionChoice.cancel),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(_LeaveSessionChoice.saveAndLeave),
                    child: const Text('저장하고 이동'),
                  ),
                ],
              ),
            );
            if (choice != _LeaveSessionChoice.saveAndLeave) return;
            // SessionScreen에서 자동 저장 실행
            ref.read(sessionAutoSaveTriggerProvider.notifier).state = true;
            // 저장이 처리될 시간을 잠시 대기
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
          if (!mounted) return;
          ref.read(shellBranchIndexProvider.notifier).state = index;
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
            tooltip: '홈 대시보드',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_calendar_outlined),
            selectedIcon: Icon(Icons.edit_calendar),
            label: '계획',
            tooltip: '오늘 계획표',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: '공부',
            tooltip: '집중 공부',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: '스터디',
            tooltip: '스터디방',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: '기록',
            tooltip: '집중 기록·미션·랭킹',
          ),
        ],
      ),
    );
  }
}
