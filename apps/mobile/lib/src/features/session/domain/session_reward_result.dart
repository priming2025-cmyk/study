class SessionRewardResult {
  final int coinsFromFocus;
  final int planBonus;
  final int streakBonus;

  const SessionRewardResult({
    required this.coinsFromFocus,
    required this.planBonus,
    required this.streakBonus,
  });

  int get total => coinsFromFocus + planBonus + streakBonus;
}

