import 'package:flutter/material.dart';

import '../domain/dream_city_state.dart';
import 'widgets/dream_city_isometric_view.dart';
import 'widgets/dream_city_tech_panel.dart';

/// 꿈의 도시 상세 — 3D 마을 + 직업 테크트리.
class DreamCityScreen extends StatelessWidget {
  final int blockCount;
  final int totalFocusMinutes;

  const DreamCityScreen({
    super.key,
    required this.blockCount,
    required this.totalFocusMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final state = DreamCityState.fromBlocks(blockCount);

    return Scaffold(
      appBar: AppBar(title: const Text('꿈의 도시')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: DreamCityIsometricView(
              blockCount: blockCount,
              height: 280,
              animate: true,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '집중 시간·계획 달성·친구와 함께 공부한 블럭으로 '
            '의사, 과학자, 개발자… 꿈의 직업 마을을 키워요.',
            style: tt.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '총 집중 $totalFocusMinutes분 · 블럭 $blockCount개 · 도시 Lv.${state.cityLevel.toStringAsFixed(1)}',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (state.placed.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('내 마을',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.placed.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final p = state.placed[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.def.emoji, style: const TextStyle(fontSize: 28)),
                          Text(p.def.nameKo,
                              style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text(p.def.branch.labelKo, style: tt.labelSmall),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (state.nextGoals.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('다음 건설 목표',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ...state.nextGoals.map(
              (d) => ListTile(
                leading: Text(d.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(d.nameKo),
                subtitle: Text(d.kidDreamLine),
                trailing: Text('${d.blockCost - blockCount}블럭'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          DreamCityTechPanel(state: state),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('프로필에 노출',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    '친구가 내 프로필을 볼 때 이 3D 마을이 함께 보여요. '
                    '더 공부할수록 우주센터·로켓 발사대까지 성장해요!',
                    style: tt.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
