import 'dream_city_tech_tree.dart';

/// 블럭 수로 해금·배치된 도시 상태.
class DreamCityState {
  final int blockCount;
  final List<DreamCityPlacedBuilding> placed;
  final List<DreamCityBuildingDef> nextGoals;
  final int gridCols;
  final int gridRows;
  final double cityLevel;

  const DreamCityState({
    required this.blockCount,
    required this.placed,
    required this.nextGoals,
    required this.gridCols,
    required this.gridRows,
    required this.cityLevel,
  });

  factory DreamCityState.fromBlocks(int blocks) {
    final builtIds = <String>{};
    final placed = <DreamCityPlacedBuilding>[];

    for (final def in dreamCityCatalog) {
      if (blocks < def.blockCost) continue;
      final prereqOk = def.requiresIds.every(builtIds.contains);
      if (!prereqOk) continue;
      builtIds.add(def.id);
      placed.add(DreamCityPlacedBuilding(def: def, builtAtBlocks: def.blockCost));
    }

    final next = dreamCityCatalog
        .where((d) => !builtIds.contains(d.id))
        .where((d) => d.requiresIds.every(builtIds.contains))
        .take(4)
        .toList();

    final level = (placed.length / dreamCityCatalog.length).clamp(0.0, 1.0);

    return DreamCityState(
      blockCount: blocks,
      placed: placed,
      nextGoals: next,
      gridCols: 5,
      gridRows: 5,
      cityLevel: level * 10,
    );
  }

  bool isTileUnlocked(int x, int y) {
    final idx = y * gridCols + x;
    if (blockCount >= 400) return true;
    if (blockCount >= 200) return idx < 20;
    if (blockCount >= 100) return idx < 12;
    if (blockCount >= 40) return idx < 6;
    return idx == 7; // center start
  }

  DreamCityPlacedBuilding? buildingAt(int x, int y) {
    for (final p in placed) {
      if (p.def.gridX == x && p.def.gridY == y) return p;
    }
    return null;
  }
}

class DreamCityPlacedBuilding {
  final DreamCityBuildingDef def;
  final int builtAtBlocks;

  const DreamCityPlacedBuilding({
    required this.def,
    required this.builtAtBlocks,
  });
}
