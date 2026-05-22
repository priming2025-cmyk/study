import 'package:flutter/material.dart';

import 'widgets/city_progress_card.dart';
import 'widgets/dream_city_isometric_view.dart';

/// 꿈의 도시 상세 — 건설·성장 게임 화면.
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
    final buildings = DreamCityIsometricView.buildingsFromBlocks(blockCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('꿈의 도시'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: DreamCityIsometricView(
              blockCount: blockCount,
              height: 260,
              interactive: true,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '집중 시간·계획 달성·친구와 함께 공부한 블럭으로 마을을 키워요.',
            style: tt.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '총 집중 ${totalFocusMinutes}분 · 보유 블럭 $blockCount개',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Text('건설된 건물', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (buildings.isEmpty)
            const Text('블럭을 모아 첫 건물을 지어 보세요!')
          else
            ...buildings.map(
              (b) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(b.emoji, style: const TextStyle(fontSize: 28)),
                  title: Text('Lv.${b.level} 건물'),
                  subtitle: const Text('집중과 계획으로 자동 성장'),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('다음 목표', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...cityBuildingCatalog.map((e) {
            final done = blockCount >= e.blocks;
            return ListTile(
              leading: Text(e.emoji, style: const TextStyle(fontSize: 22)),
              title: Text(e.name),
              subtitle: Text('블럭 ${e.blocks}개 필요'),
              trailing: done
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : Text('${e.blocks - blockCount}개 남음'),
            );
          }),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '프로필에 노출',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '친구가 내 프로필을 볼 때 이 마을 미리보기가 함께 보여요. '
                    '셋터디·기록에서 성장한 도시를 자랑해 보세요.',
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
