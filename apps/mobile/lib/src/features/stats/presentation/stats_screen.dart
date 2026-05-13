import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../motivation/domain/motivation_models.dart';
import '../../session/domain/wallet_balances.dart';
import '../data/daily_focus_stat.dart';

String formatFocusDuration(int seconds) {
  if (seconds <= 0) return '0분';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '$h시간 $m분';
  return '$m분';
}

class _StatsPayload {
  final List<DailyFocusStat> stats;
  final WalletBalances wallet;
  final ProfileRpgSummary? rpg;
  final List<FriendRankRow> ranks;
  final List<SquadRow> squads;
  final Map<String, Map<String, dynamic>> squadProgress;

  const _StatsPayload({
    required this.stats,
    required this.wallet,
    required this.rpg,
    required this.ranks,
    required this.squads,
    required this.squadProgress,
  });
}

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  late Future<_StatsPayload> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatsPayload> _load() async {
    final sessionRepo = ref.read(sessionRepositoryProvider);
    final motivationRepo = ref.read(motivationRepositoryProvider);
    final stats = await sessionRepo.fetchDailyFocusLastDays(7);
    final wallet = await sessionRepo.fetchWalletBalances();
    final rpg = await motivationRepo.fetchMyProfileRpg();
    final ranks = await motivationRepo.friendWeekRankings();
    final squads = await motivationRepo.mySquads();
    final prog = <String, Map<String, dynamic>>{};
    for (final s in squads) {
      prog[s.id] = await motivationRepo.squadWeekProgress(s.id);
    }
    return _StatsPayload(
      stats: stats,
      wallet: wallet,
      rpg: rpg,
      ranks: ranks,
      squads: squads,
      squadProgress: prog,
    );
  }

  Future<void> _onRefresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  static String _rankFmt(int sec) {
    if (sec <= 0) return '0분';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분';
    return '$m분';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final email = supabase.auth.currentUser?.email;
    // 계급은 자동으로 올라가며, 기록 화면에서는 별도 "착용" UI를 노출하지 않습니다.

    return Scaffold(
      appBar: AppBar(
        title: const Text('기록'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_StatsPayload>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '불러오지 못했어요.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          final p = snapshot.data!;
          final stats = p.stats;
          final maxSec = stats.fold<int>(
            1,
            (m, e) => e.focusedSeconds > m ? e.focusedSeconds : m,
          );
          final total = stats.fold<int>(0, (a, e) => a + e.focusedSeconds);

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '나의 정보',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.rpg != null)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.rpg!.currentRankKo ?? '집중 중',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        if (email != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            email,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                        const Divider(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => context.push('/coins'),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Icon(Icons.toll_outlined, color: scheme.primary),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '블럭 ${p.wallet.blocks} · 코인 ${p.wallet.redeemCoins} · 내역',
                                          style: Theme.of(context).textTheme.titleSmall,
                                        ),
                                      ),
                                      Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () => context.push('/coins/how'),
                              child: const Text('모으는 방법'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '이번 주 미션',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '챌린지 팀 합산 집중 시간으로 진행도가 채워져요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                if (p.squads.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '참여 중인 팀이 없어요.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/social'),
                            icon: const Icon(Icons.groups_2_outlined),
                            label: const Text('함께하기에서 팀 만들기'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...p.squads.map((s) {
                    final prog = p.squadProgress[s.id];
                    final ratio = prog == null
                        ? 0.0
                        : ((prog['ratio'] ?? 0) as num).toDouble();
                    final sec = prog == null
                        ? 0
                        : ((prog['team_focused_seconds'] ?? 0) as num).toInt();
                    final hours =
                        (s.missionTargetSeconds / 3600).toStringAsFixed(s.missionTargetSeconds % 3600 == 0 ? 0 : 1);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: Theme.of(context).textTheme.titleSmall),
                            Text(
                              '목표 $hours시간 · 합산 ${_rankFmt(sec)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: ratio.clamp(0.0, 1.0)),
                            Text(
                              '${(ratio * 100).round()}%',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      '친구 주간 랭킹',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => context.push('/social'),
                      icon: const Icon(Icons.groups_2_outlined, size: 18),
                      label: const Text('함께하기'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '월~일 집중 시간 합산 · 친구를 맺으면 표시돼요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                if (p.ranks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '아직 순위 데이터가 없어요.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  )
                else
                  ...p.ranks.map(
                    (r) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${r.rank}')),
                        title: Text(r.displayName),
                        subtitle: Text(_rankFmt(r.focusedSeconds)),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  '최근 7일 집중',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0
                      ? '세션을 끝내면 여기에 쌓여요.'
                      : '합계 ${formatFocusDuration(total)} · 그래프는 가장 긴 날 기준이에요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                ...stats.map((e) => _DayRow(stat: e, maxSeconds: maxSec)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.stat, required this.maxSeconds});

  final DailyFocusStat stat;
  final int maxSeconds;

  static String _weekdayShort(DateTime d) {
    return switch (d.weekday) {
      DateTime.monday => '월',
      DateTime.tuesday => '화',
      DateTime.wednesday => '수',
      DateTime.thursday => '목',
      DateTime.friday => '금',
      DateTime.saturday => '토',
      _ => '일',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = maxSeconds <= 0 ? 0.0 : stat.focusedSeconds / maxSeconds;
    final label =
        '${stat.dayLocal.month}/${stat.dayLocal.day} (${_weekdayShort(stat.dayLocal)})';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text(
              formatFocusDuration(stat.focusedSeconds),
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
