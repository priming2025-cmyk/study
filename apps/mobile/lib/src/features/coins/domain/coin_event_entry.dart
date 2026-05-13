class CoinEventEntry {
  final String id;
  final String kind;
  /// 양(+적립 / -차감). [asset]이 블럭이면 앱 내 보상, 교환 코인이면 스토어용.
  final int coins;
  final String asset;
  final DateTime createdAt;
  final String? sessionId;
  final DateTime? planDate;

  const CoinEventEntry({
    required this.id,
    required this.kind,
    required this.coins,
    required this.asset,
    required this.createdAt,
    this.sessionId,
    this.planDate,
  });
}
