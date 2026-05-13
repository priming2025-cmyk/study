/// 앱 내 보상 **블럭**과 기프티콘 등에 쓰는 **코인(교환 코인)** 잔고.
class WalletBalances {
  final int blocks;
  final int redeemCoins;

  const WalletBalances({
    required this.blocks,
    required this.redeemCoins,
  });

  static const WalletBalances zero = WalletBalances(blocks: 0, redeemCoins: 0);

  factory WalletBalances.fromRow(Map<String, dynamic>? row) {
    if (row == null) return WalletBalances.zero;
    return WalletBalances(
      blocks: ((row['block_balance'] ?? 0) as num).toInt(),
      redeemCoins: ((row['redeem_coin_balance'] ?? 0) as num).toInt(),
    );
  }
}
