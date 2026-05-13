/// RPG / 소셜 / 가챠 관련 클라이언트 모델 (경량).
class ProfileRpgSummary {
  final int xpTotal;
  final int level;
  final int streakCurrent;
  final int streakBest;
  final String? equippedTitleKo;
  final String? currentRankKo;
  final String? nextRankKo;
  final int? xpToNextRank;
  final String? equippedBorderKey;

  const ProfileRpgSummary({
    required this.xpTotal,
    required this.level,
    required this.streakCurrent,
    required this.streakBest,
    this.equippedTitleKo,
    this.currentRankKo,
    this.nextRankKo,
    this.xpToNextRank,
    this.equippedBorderKey,
  });

  factory ProfileRpgSummary.fromProfileRow(
    Map<String, dynamic> row, {
    String? titleKo,
    String? currentRankKo,
    String? nextRankKo,
    int? xpToNextRank,
  }) {
    return ProfileRpgSummary(
      xpTotal: ((row['xp_total'] ?? 0) as num).toInt(),
      level: ((row['level'] ?? 1) as num).toInt(),
      streakCurrent: ((row['streak_current'] ?? 0) as num).toInt(),
      streakBest: ((row['streak_best'] ?? 0) as num).toInt(),
      equippedTitleKo: titleKo,
      currentRankKo: currentRankKo,
      nextRankKo: nextRankKo,
      xpToNextRank: xpToNextRank,
      equippedBorderKey: row['equipped_border_key'] as String?,
    );
  }
}

class FriendRow {
  final String peerId;
  final String displayName;
  final int level;

  const FriendRow({
    required this.peerId,
    required this.displayName,
    required this.level,
  });
}

class FriendRankRow {
  final String peerId;
  final String displayName;
  final int focusedSeconds;
  final int rank;

  const FriendRankRow({
    required this.peerId,
    required this.displayName,
    required this.focusedSeconds,
    required this.rank,
  });
}

class SquadRow {
  final String id;
  final String name;
  final int missionTargetSeconds;

  const SquadRow({
    required this.id,
    required this.name,
    required this.missionTargetSeconds,
  });
}

class CosmeticItemRow {
  final String id;
  final String key;
  final String nameKo;
  final String kind;
  final String rarity;

  const CosmeticItemRow({
    required this.id,
    required this.key,
    required this.nameKo,
    required this.kind,
    required this.rarity,
  });
}
