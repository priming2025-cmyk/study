import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_up/l10n/app_localizations.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../motivation/domain/motivation_models.dart';
import '../../plan/data/plan_models.dart';
import 'widgets/dashboard_hero_streak.dart';
import 'widgets/dashboard_quick_card.dart';
import 'widgets/dashboard_today_section.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final email = supabase.auth.currentUser?.email;
    final planRepo = ref.watch(planRepositoryProvider);
    final sessionRepo = ref.watch(sessionRepositoryProvider);
    final motivationRepo = ref.watch(motivationRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
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
          motivationRepo.fetchMyProfileRpg(),
        ]),
        builder: (context, snapshot) {
          final focusedSeconds =
              snapshot.data == null ? 0 : snapshot.data![0] as int;
          final todayPlan =
              snapshot.data == null ? null : snapshot.data![1] as TodayPlan?;
          final rpg = snapshot.data == null ? null : snapshot.data![2] as ProfileRpgSummary?;

          final planTarget = todayPlan?.totalTargetSeconds ?? 0;
          final planActual = todayPlan?.totalActualSeconds ?? 0;
          final completionRate = planTarget <= 0
              ? 0.0
              : (planActual / planTarget).clamp(0.0, 1.0);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DashboardHeroCard(
                email: email,
                rpg: rpg,
              ),
              const SizedBox(height: 12),
              DashboardTodayMetricsCard(
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
                    child: DashboardQuickCard(
                      title: '오늘 계획',
                      subtitle: '템플릿/최근 과목',
                      icon: Icons.edit_calendar_outlined,
                      onTap: () => context.go('/plan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DashboardQuickCard(
                      title: '기록',
                      subtitle: '최근 7일 집중',
                      icon: Icons.insights_outlined,
                      onTap: () => context.go('/stats'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => context.go('/family'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.volunteer_activism_outlined,
                        size: 22,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '서포터 연결 · 요약 공유 · 블럭→코인',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
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
                        onPressed: () => context.go('/session/quick'),
                        icon: const Icon(Icons.timer),
                        label: const Text('1초 만에 집중 시작'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/room/quick'),
                        icon: const Icon(Icons.groups),
                        label: const Text('스터디방 빠른 입장'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '얼굴/영상은 서버로 보내지 않아요. 공부 요약만 저장해요.',
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
              Text(
                '동기·보상',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 6),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '꾸준함은 기록 탭에서 확인해요',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '최근 7일 집중 그래프, 블럭·코인 내역, 친구 랭킹을 한 번에 볼 수 있어요.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/social'),
                      icon: const Icon(Icons.groups_2_outlined),
                      label: const Text('함께하기'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/gacha'),
                      icon: const Icon(Icons.card_giftcard_outlined),
                      label: const Text('뽑기'),
                    ),
                  ),
                ],
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
