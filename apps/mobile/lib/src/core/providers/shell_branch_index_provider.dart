import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 하단 네비 `StatefulNavigationShell` 브랜치 인덱스.
/// 0=홈, 1=계획, 2=공부(세션), 3=스터디, 4=기록
const kShellBranchHome = 0;
const kShellBranchPlan = 1;
const kShellBranchSession = 2;
const kShellBranchStudy = 3;
const kShellBranchStats = 4;

final shellBranchIndexProvider = StateProvider<int>((ref) => 0);

/// 공부 세션이 현재 실행 중인지 여부 (SessionScreen → AppShell로 상태 공유).
final sessionRunningProvider = StateProvider<bool>((ref) => false);

/// 공부 세션 자동 저장 트리거: AppShell이 true로 설정하면 SessionScreen이 감지해 저장.
final sessionAutoSaveTriggerProvider = StateProvider<bool>((ref) => false);

/// 스터디방에 입장해 있는지(StudyRoomScreen이 갱신). 하단 탭 이탈 가드에 사용.
final studyRoomInRoomProvider = StateProvider<bool>((ref) => false);

/// 스터디 탭에서 나갈 때 방만 나가야 하면 증가시키고 StudyRoomScreen이 [leave] 처리.
final studyRoomLeaveForTabSwitchProvider = StateProvider<int>((ref) => 0);
