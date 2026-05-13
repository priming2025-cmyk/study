import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/coin_repository.dart';

class CoinEarningGuideScreen extends StatelessWidget {
  const CoinEarningGuideScreen({super.key});

  Widget _tipTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kindRow(BuildContext context, {required String kind, required String desc}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              CoinRepository.kindLabelKo(kind),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              desc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('블럭 모으는 방법'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.surfaceContainerHighest.withAlpha(160),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '앱 안 보상은 블럭이에요. “공부 종료 → 기록 반영” 과정에서 쌓입니다.',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '기프티콘 등에 쓰는 코인(교환 코인)은 서포터가 블럭을 바꿔 줄 때 생기고, 유료 충전·스토어는 추후 연동 예정이에요.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '공부를 “끝내기”까지 해야 내역에 남습니다. 아래 3가지가 블럭 내역에 기록돼요.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('내역에 이렇게 표시돼요', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _kindRow(
            context,
            kind: 'focused_time',
            desc: '집중 공부를 종료하면 기록에 반영돼요. (집중 시간이 0이면 블럭이 없을 수 있어요.)',
          ),
          _kindRow(
            context,
            kind: 'plan_80_bonus',
            desc: '하루 계획 달성률이 80% 이상이면 “계획 달성 보너스”가 추가로 기록됩니다.',
          ),
          _kindRow(
            context,
            kind: 'streak_bonus_50',
            desc: '어제와 오늘 모두 “계획 달성 보너스” 조건을 만족하면 “연속 달성 보너스(+50)”가 기록됩니다.',
          ),
          const SizedBox(height: 12),
          _tipTile(
            context,
            icon: Icons.flag_outlined,
            title: '블럭이 안 쌓일 때 가장 흔한 이유',
            body: '공부를 “종료”하지 않았거나, 종료 직후 기록 반영(업로드)이 실패한 경우예요. 먼저 공부를 끝낸 뒤, 기록 탭에서 새로고침을 해 보세요.',
          ),
          _tipTile(
            context,
            icon: Icons.task_alt_outlined,
            title: '계획 보너스를 빠르게 받는 루틴',
            body: '오늘 계획(목표 시간)을 현실적으로 잡고, 공부를 여러 번 끝내서 실제 집중 시간이 계획의 80%를 넘기면 보너스가 들어와요.',
          ),
          _tipTile(
            context,
            icon: Icons.local_fire_department_outlined,
            title: '연속 보너스(+50) 노리는 방법',
            body: '핵심은 “이틀 연속” 계획 80% 달성이에요. 하루만 채우면 연속 보너스는 안 뜨고, 다음 날까지 이어졌을 때 기록됩니다.',
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/coins'),
            icon: const Icon(Icons.toll_outlined),
            label: const Text('보상 내역 보기'),
          ),
        ],
      ),
    );
  }
}

