class CoinEventEntry {
  final String id;
  final String kind;
  final int coins;
  final DateTime createdAt;
  final String? sessionId;
  final DateTime? planDate;

  const CoinEventEntry({
    required this.id,
    required this.kind,
    required this.coins,
    required this.createdAt,
    this.sessionId,
    this.planDate,
  });
}
