import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 하단 네비 `StatefulNavigationShell` 브랜치 인덱스.
/// 0=공부(세션), 1=계획, 2=셋터디, 3=기록
const kShellBranchSession = 0;
const kShellBranchPlan = 1;
const kShellBranchStudy = 2;
const kShellBranchStats = 3;

final shellBranchIndexProvider = StateProvider<int>((ref) => 0);

/// 공부 세션이 현재 실행 중인지 여부 (SessionScreen → AppShell로 상태 공유).
final sessionRunningProvider = StateProvider<bool>((ref) => false);

/// 공부 세션 자동 저장 트리거: AppShell이 true로 설정하면 SessionScreen이 감지해 저장.
final sessionAutoSaveTriggerProvider = StateProvider<bool>((ref) => false);

/// 스터디방에 입장해 있는지(StudyRoomScreen이 갱신). 하단 탭 이탈 가드에 사용.
final studyRoomInRoomProvider = StateProvider<bool>((ref) => false);

/// 스터디 탭에서 나갈 때 방만 나가야 하면 증가시키고 StudyRoomScreen이 [leave] 처리.
final studyRoomLeaveForTabSwitchProvider = StateProvider<int>((ref) => 0);

/// 오늘 계획이 바뀌면 증가 — 집중공부 탭이 목록을 다시 불러옵니다.
final todayPlanRevisionProvider = StateProvider<int>((ref) => 0);

/// 계획 탭 → 집중공부: 이 id 항목을 선택한 뒤 공부 시작하도록 유도.
final sessionPendingPlanItemIdProvider = StateProvider<String?>((ref) => null);
