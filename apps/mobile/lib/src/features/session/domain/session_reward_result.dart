class SessionRewardResult {
  /// 집중 세션으로 받은 **블럭**.
  final int blocksFromFocus;
  final int planBonus;
  final int streakBonus;

  const SessionRewardResult({
    required this.blocksFromFocus,
    required this.planBonus,
    required this.streakBonus,
  });

  /// 총 **블럭** (앱 내 보상 단위).
  int get totalBlocks => blocksFromFocus + planBonus + streakBonus;
}

