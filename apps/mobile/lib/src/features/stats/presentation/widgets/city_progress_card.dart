import 'package:flutter/material.dart';

/// 꿈의 도시 — 섹터 기반 건설 게임 카드.
/// 2×2 → 3×3 그리드 확장, 건물 Lv.1~8, 블럭으로 섹터·건물 구매.
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

  int get _gridSize {
    if (blockCount >= 300) return 3;
    if (blockCount >= 80) return 3;
    return 2;
  }

  int get _unlockedSectors {
    final max = _gridSize * _gridSize;
    if (blockCount >= 200) return max;
    if (blockCount >= 120) return max - 1;
    if (blockCount >= 60) return max - 2;
    if (blockCount >= 30) return 3;
    if (blockCount >= 10) return 2;
    return 1;
  }

  List<_CityBuilding> get _placed => _buildingsForBlocks(blockCount);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final grid = _gridSize;
    final placed = _placed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E293B),
            ],
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
                        '블럭 $blockCount · $grid×$grid 마을',
                        style: tt.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: grid,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: grid * grid,
                itemBuilder: (context, i) {
                  final unlocked = i < _unlockedSectors;
                  final building = i < placed.length ? placed[i] : null;
                  return _SectorTile(
                    unlocked: unlocked,
                    building: building,
                    index: i,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _nextHint(blockCount),
              style: tt.labelSmall?.copyWith(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  String _nextHint(int blocks) {
    if (blocks < 10) return '블럭 10개 → 2번째 섹터 해금';
    if (blocks < 30) return '블럭 30개 → 3번째 섹터 해금';
    if (blocks < 80) return '블럭 80개 → 3×3 도시 확장';
    if (blocks < 120) return '블럭 120개 → 병원 Lv.3 건설 가능';
    return '더 높은 레벨 건물을 위해 블럭을 모아보세요';
  }

  static List<_CityBuilding> _buildingsForBlocks(int blocks) {
    final list = <_CityBuilding>[];
    if (blocks >= 10) {
      list.add(const _CityBuilding(name: '집', emoji: '🏠', level: 1, sectors: 1));
    }
    if (blocks >= 30) {
      list.add(const _CityBuilding(name: '학교', emoji: '🏫', level: 2, sectors: 1));
    }
    if (blocks >= 60) {
      list.add(const _CityBuilding(name: '도서관', emoji: '📚', level: 3, sectors: 2));
    }
    if (blocks >= 100) {
      list.add(const _CityBuilding(name: '공원', emoji: '🌳', level: 4, sectors: 2));
    }
    if (blocks >= 150) {
      list.add(const _CityBuilding(name: '병원', emoji: '🏥', level: 5, sectors: 3));
    }
    if (blocks >= 220) {
      list.add(const _CityBuilding(name: '법원', emoji: '⚖️', level: 6, sectors: 3));
    }
    if (blocks >= 300) {
      list.add(const _CityBuilding(name: '시청', emoji: '🏛️', level: 7, sectors: 4));
    }
    if (blocks >= 500) {
      list.add(const _CityBuilding(name: '대학', emoji: '🎓', level: 8, sectors: 4));
    }
    return list;
  }
}

class _CityBuilding {
  final String name;
  final String emoji;
  final int level;
  final int sectors;

  const _CityBuilding({
    required this.name,
    required this.emoji,
    required this.level,
    required this.sectors,
  });
}

class _SectorTile extends StatelessWidget {
  final bool unlocked;
  final _CityBuilding? building;
  final int index;

  const _SectorTile({
    required this.unlocked,
    required this.building,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    if (!unlocked) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Icon(Icons.lock_outline, color: Colors.white24, size: 18),
        ),
      );
    }

    if (building == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Icon(Icons.add_rounded, color: Colors.white54, size: 20),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.amber.withValues(alpha: 0.25),
            Colors.orange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(building!.emoji, style: const TextStyle(fontSize: 22)),
          Text(
            'Lv.${building!.level}',
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 건물 카탈로그 (Lv.1~8, 섹터 요구)
const cityBuildingCatalog = [
  (name: '오두막', emoji: '🏠', level: 1, sectors: 1, blocks: 10),
  (name: '학교', emoji: '🏫', level: 2, sectors: 1, blocks: 30),
  (name: '도서관', emoji: '📚', level: 3, sectors: 2, blocks: 60),
  (name: '카페', emoji: '☕', level: 4, sectors: 2, blocks: 100),
  (name: '병원', emoji: '🏥', level: 5, sectors: 3, blocks: 150),
  (name: '법원', emoji: '⚖️', level: 6, sectors: 3, blocks: 220),
  (name: '시청', emoji: '🏛️', level: 7, sectors: 4, blocks: 300),
  (name: '대학교', emoji: '🎓', level: 8, sectors: 4, blocks: 500),
];
