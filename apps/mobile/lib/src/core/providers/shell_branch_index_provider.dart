import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 하단 네비 `StatefulNavigationShell` 브랜치 인덱스.
/// 0=홈, 1=계획, 2=공부(세션), 3=스터디, 4=기록
const kShellBranchHome = 0;
const kShellBranchPlan = 1;
const kShellBranchSession = 2;
const kShellBranchStudy = 3;
const kShellBranchStats = 4;

final shellBranchIndexProvider = StateProvider<int>((ref) => 0);
