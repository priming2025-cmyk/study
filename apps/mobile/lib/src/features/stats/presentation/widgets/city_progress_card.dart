import 'package:flutter/material.dart';

import '../../domain/dream_city_state.dart';
import 'dream_city_isometric_view.dart';

/// 꿈의 도시 — 3D 마을 미리보기 카드.
class CityProgressCard extends StatelessWidget {
  final int blockCount;
  final int totalFocusMinutes;
  final VoidCallback? onTap;

  const CityProgressCard({
    super.key,
    required this.blockCount,
    required this.totalFocusMinutes,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final state = DreamCityState.fromBlocks(blockCount);
    final next = state.nextGoals.isNotEmpty ? state.nextGoals.first : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏙️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '꿈의 도시',
                        style: tt.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Lv.${state.cityLevel.toStringAsFixed(1)} · 건물 ${state.placed.length}개 · 집중 ${totalFocusMinutes}분',
                        style: tt.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🧱', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '$blockCount',
                        style: tt.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DreamCityIsometricView(
                blockCount: blockCount,
                height: 200,
              ),
            ),
            if (state.placed.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.placed.length.clamp(0, 8),
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final p = state.placed[i];
                    return Container(
                      width: 72,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(p.def.emoji, style: const TextStyle(fontSize: 20)),
                          Text(
                            p.def.nameKo,
                            style: tt.labelSmall?.copyWith(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              next != null
                  ? '다음: ${next.emoji} ${next.nameKo} (${next.blockCost - blockCount}블럭)'
                  : '모든 꿈 건물을 완성했어요!',
              style: tt.labelSmall?.copyWith(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
