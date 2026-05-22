import 'package:flutter/material.dart';

/// 꿈의 도시 건설 진행 카드.
/// 누적 블럭 수에 따라 도시 건물이 단계적으로 언락됩니다.
class CityProgressCard extends StatefulWidget {
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
  State<CityProgressCard> createState() => _CityProgressCardState();
}

class _CityProgressCardState extends State<CityProgressCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final buildings = _getBuildingsUnlocked(widget.blockCount);
    final nextBuilding = _getNextBuilding(widget.blockCount);
    final progress = _getProgressToNext(widget.blockCount);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A237E).withValues(alpha: 0.9),
              const Color(0xFF283593).withValues(alpha: 0.9),
              const Color(0xFF1565C0).withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A237E).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏙️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '나의 꿈의 도시',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '블럭 ${widget.blockCount}개 · 건물 ${buildings.length}개 완성',
                        style: tt.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🧱', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.blockCount}',
                        style: tt.labelMedium?.copyWith(
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
            // 도시 건물 아이콘 행
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  ..._allBuildings.asMap().entries.map((e) {
                    final building = e.value;
                    final isUnlocked = widget.blockCount >= building.requiredBlocks;
                    return Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: isUnlocked ? 1.0 : 0.25,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              building.emoji,
                              style: TextStyle(
                                fontSize: isUnlocked ? 24 : 18,
                              ),
                            ),
                            Text(
                              building.name,
                              style: TextStyle(
                                fontSize: 8,
                                color: isUnlocked
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                                fontWeight: isUnlocked
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            // 다음 건물 진행률
            if (nextBuilding != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    '다음: ${nextBuilding.emoji} ${nextBuilding.name}',
                    style: tt.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.blockCount} / ${nextBuilding.requiredBlocks} 블럭',
                    style: tt.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  color: Colors.amber.shade300,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_BuildingData> _getBuildingsUnlocked(int blocks) =>
      _allBuildings.where((b) => blocks >= b.requiredBlocks).toList();

  _BuildingData? _getNextBuilding(int blocks) {
    try {
      return _allBuildings.firstWhere((b) => blocks < b.requiredBlocks);
    } catch (_) {
      return null;
    }
  }

  double _getProgressToNext(int blocks) {
    final next = _getNextBuilding(blocks);
    if (next == null) return 1.0;
    final prev = _allBuildings.lastWhere(
      (b) => blocks >= b.requiredBlocks,
      orElse: () => const _BuildingData(name: '', emoji: '', requiredBlocks: 0),
    );
    final range = next.requiredBlocks - prev.requiredBlocks;
    if (range <= 0) return 0.0;
    return ((blocks - prev.requiredBlocks) / range).clamp(0.0, 1.0);
  }
}

class _BuildingData {
  final String name;
  final String emoji;
  final int requiredBlocks;

  const _BuildingData({
    required this.name,
    required this.emoji,
    required this.requiredBlocks,
  });
}

const _allBuildings = [
  _BuildingData(name: '오두막', emoji: '🏠', requiredBlocks: 10),
  _BuildingData(name: '학교', emoji: '🏫', requiredBlocks: 30),
  _BuildingData(name: '도서관', emoji: '📚', requiredBlocks: 60),
  _BuildingData(name: '공원', emoji: '🌳', requiredBlocks: 100),
  _BuildingData(name: '카페', emoji: '☕', requiredBlocks: 150),
  _BuildingData(name: '시청', emoji: '🏛️', requiredBlocks: 300),
  _BuildingData(name: '대학교', emoji: '🎓', requiredBlocks: 500),
];
