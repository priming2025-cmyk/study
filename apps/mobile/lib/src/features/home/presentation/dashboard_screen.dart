import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_up/l10n/app_localizations.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../plan/data/plan_models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final email = supabase.auth.currentUser?.email;
    final planRepo = ref.watch(planRepositoryProvider);
    final sessionRepo = ref.watch(sessionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study-up'),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            onPressed: () async {
              await supabase.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder(
        future: Future.wait([
          sessionRepo.fetchTodayFocusedSeconds(),
          planRepo.fetchTodayPlan(),
          sessionRepo.fetchCoinBalance(),
        ]),
        builder: (context, snapshot) {
          final focusedSeconds =
              snapshot.data == null ? 0 : snapshot.data![0] as int;
          final todayPlan =
              snapshot.data == null ? null : snapshot.data![1] as TodayPlan?;
          final coinBalance =
              snapshot.data == null ? 0 : snapshot.data![2] as int;

          final planTarget = todayPlan?.totalTargetSeconds ?? 0;
          final planActual = todayPlan?.totalActualSeconds ?? 0;
          final completionRate = planTarget <= 0
              ? 0.0
              : (planActual / planTarget).clamp(0.0, 1.0);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeroCard(email: email, coinBalance: coinBalance),
              const SizedBox(height: 12),
              _TodayMetricsCard(
                focusedSeconds: focusedSeconds,
                planTargetSeconds: planTarget,
                planActualSeconds: planActual,
                completionRate: completionRate,
                loading: snapshot.connectionState == ConnectionState.waiting,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickCard(
                      title: '오늘 계획',
                      subtitle: '템플릿/최근 과목',
                      icon: Icons.edit_calendar_outlined,
                      onTap: () => context.go('/plan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickCard(
                      title: '기록',
                      subtitle: '최근 7일 집중',
                      icon: Icons.insights_outlined,
                      onTap: () => context.go('/stats'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _QuickCard(
                title: '가족 연결',
                subtitle: '부모·자녀 집중 기록 공유',
                icon: Icons.family_restroom_outlined,
                onTap: () => context.go('/family'),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('바로 시작',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => context.go('/session'),
                        icon: const Icon(Icons.timer),
                        label: const Text('집중 세션 시작'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/room'),
                        icon: const Icon(Icons.groups),
                        label: const Text('스터디방 들어가기'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '얼굴/영상은 서버로 보내지 않아요. 세션 요약만 저장해요.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/legal/terms'),
                      child: Text(l10n.termsOfService),
                    ),
                    TextButton(
                      onPressed: () => context.push('/legal/privacy'),
                      child: Text(l10n.privacyPolicy),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String? email;
  final int coinBalance;
  const _HeroCard({required this.email, required this.coinBalance});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘도 꾸준히',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '계획 → 집중 → 기록 → 분석',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => context.push('/coins'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.toll_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '코인 $coinBalance · 내역 보기',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (email != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      email!,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayMetricsCard extends StatelessWidget {
  final int focusedSeconds;
  final int planTargetSeconds;
  final int planActualSeconds;
  final double completionRate;
  final bool loading;

  const _TodayMetricsCard({
    required this.focusedSeconds,
    required this.planTargetSeconds,
    required this.planActualSeconds,
    required this.completionRate,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final focusedText = _formatSeconds(focusedSeconds);
    final planText = planTargetSeconds <= 0
        ? '아직 계획이 없어요'
        : '${_formatSeconds(planActualSeconds)} / ${_formatSeconds(planTargetSeconds)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('오늘',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: '집중시간',
                    value: loading ? '불러오는 중…' : focusedText,
                    icon: Icons.timer_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    label: '계획 달성률',
                    value: loading
                        ? '불러오는 중…'
                        : '${(completionRate * 100).round()}%',
                    icon: Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(planText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: completionRate),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

