import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 학교급 분류
enum SchoolLevel {
  middle('중학교', Icons.school_outlined),
  high('고등학교', Icons.account_balance_outlined),
  university('대학교', Icons.school_rounded);

  final String label;
  final IconData icon;
  const SchoolLevel(this.label, this.icon);
}

/// 그룹 정렬 기준
enum GroupSortBy {
  focusScore('집중점수 높은 순'),
  vacancy('빈 자리 있는 순');

  final String label;
  const GroupSortBy(this.label);
}

/// 공개 스터디 그룹 모델
class PublicStudyGroup {
  final String id;
  final String name;
  final SchoolLevel level;
  final int memberCount;
  final int maxMembers;
  final double avgFocusScore;
  final int weeklyFocusMinutes;
  final String? missionTitle;
  final double missionProgress;

  const PublicStudyGroup({
    required this.id,
    required this.name,
    required this.level,
    required this.memberCount,
    required this.maxMembers,
    required this.avgFocusScore,
    required this.weeklyFocusMinutes,
    this.missionTitle,
    required this.missionProgress,
  });

  bool get haVacancy => memberCount < maxMembers;
  int get vacancyCount => maxMembers - memberCount;
}

/// 그룹 탐색 바텀시트 — 중학교/고등학교/대학교 별 공개 스터디 그룹 탐색 및 가입 신청.
class StudyGroupBrowserSheet extends StatefulWidget {
  final void Function(PublicStudyGroup group) onApply;

  const StudyGroupBrowserSheet({super.key, required this.onApply});

  @override
  State<StudyGroupBrowserSheet> createState() => _StudyGroupBrowserSheetState();
}

class _StudyGroupBrowserSheetState extends State<StudyGroupBrowserSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GroupSortBy _sortBy = GroupSortBy.focusScore;
  bool _loading = false;
  List<PublicStudyGroup> _groups = const [];
  SchoolLevel _currentLevel = SchoolLevel.middle;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: SchoolLevel.values.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final level = SchoolLevel.values[_tabController.index];
      setState(() => _currentLevel = level);
      _loadGroups(level);
    });
    _loadGroups(SchoolLevel.middle);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups(SchoolLevel level) async {
    setState(() => _loading = true);
    try {
      final orderCol = _sortBy == GroupSortBy.focusScore
          ? 'avg_focus_score'
          : 'vacancy_count';

      final result = await Supabase.instance.client
          .from('public_study_groups')
          .select(
              'id, name, level, member_count, max_members, avg_focus_score, weekly_focus_minutes, mission_title, mission_progress')
          .eq('level', level.name)
          .eq('is_open', true)
          .order(orderCol, ascending: false)
          .limit(30);

      if (!mounted) return;
      setState(() {
        _groups = (result as List).map((row) {
          final levelStr = row['level'] as String? ?? 'middle';
          return PublicStudyGroup(
            id: row['id'] as String,
            name: row['name'] as String? ?? '스터디 그룹',
            level: SchoolLevel.values
                .firstWhere((l) => l.name == levelStr,
                    orElse: () => SchoolLevel.middle),
            memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
            maxMembers: (row['max_members'] as num?)?.toInt() ?? 10,
            avgFocusScore:
                (row['avg_focus_score'] as num?)?.toDouble() ?? 0.0,
            weeklyFocusMinutes:
                (row['weekly_focus_minutes'] as num?)?.toInt() ?? 0,
            missionTitle: row['mission_title'] as String?,
            missionProgress:
                (row['mission_progress'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyToGroup(PublicStudyGroup group) async {
    HapticFeedback.mediumImpact();
    try {
      await Supabase.instance.client.from('group_join_requests').insert({
        'group_id': group.id,
        'user_id': Supabase.instance.client.auth.currentUser?.id,
        'status': 'pending',
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onApply(group);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신청 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('그룹 찾기',
                              style: tt.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            '함께 공부하고 미션을 달성하는 스터디 그룹에 참여하세요',
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 정렬 옵션
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: GroupSortBy.values.map((sort) {
                    final sel = _sortBy == sort;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(sort.label,
                            style: const TextStyle(fontSize: 12)),
                        selected: sel,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          setState(() => _sortBy = sort);
                          _loadGroups(_currentLevel);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              // 학교급 탭바
              TabBar(
                controller: _tabController,
                tabs: SchoolLevel.values
                    .map((l) => Tab(
                          icon: Icon(l.icon, size: 18),
                          text: l.label,
                          height: 48,
                        ))
                    .toList(),
                labelColor: cs.primary,
                unselectedLabelColor: cs.onSurfaceVariant,
                indicatorColor: cs.primary,
              ),
              // 그룹 목록
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _groups.isEmpty
                        ? _EmptyGroups(cs: cs, tt: tt)
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: _groups.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _GroupCard(
                              group: _groups[i],
                              onApply: () => _applyToGroup(_groups[i]),
                              cs: cs,
                              tt: tt,
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  final PublicStudyGroup group;
  final VoidCallback onApply;
  final ColorScheme cs;
  final TextTheme tt;

  const _GroupCard({
    required this.group,
    required this.onApply,
    required this.cs,
    required this.tt,
  });

  String _fmtMinutes(int m) {
    if (m < 60) return '$m분';
    final h = m ~/ 60;
    final rem = m % 60;
    if (rem == 0) return '$h시간';
    return '$h시간 $rem분';
  }

  @override
  Widget build(BuildContext context) {
    final hasVacancy = group.haVacancy;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasVacancy ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant,
          width: hasVacancy ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              // 집중점수 배지
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded,
                        size: 12, color: cs.onTertiaryContainer),
                    const SizedBox(width: 3),
                    Text(
                      '${group.avgFocusScore.toStringAsFixed(0)}점',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.people_outline, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '${group.memberCount}/${group.maxMembers}명',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (hasVacancy) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    '${group.vacancyCount}자리 남음',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Icon(Icons.timer_outlined, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '이번 주 ${_fmtMinutes(group.weeklyFocusMinutes)}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          if (group.missionTitle != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 14, color: cs.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    group.missionTitle!,
                    style: tt.bodySmall?.copyWith(color: cs.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(group.missionProgress * 100).round()}%',
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: group.missionProgress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: cs.surfaceContainerHighest,
                color: cs.primary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: hasVacancy
                ? FilledButton(
                    onPressed: onApply,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('가입 신청'),
                  )
                : OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('인원 마감'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;

  const _EmptyGroups({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off_outlined,
              size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            '아직 공개 그룹이 없어요',
            style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            '친구를 초대해서 직접 만들어보세요!',
            style: tt.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}
