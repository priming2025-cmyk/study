import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/coin_event_entry.dart';

class CoinRepository {
  const CoinRepository();

  Future<List<CoinEventEntry>> fetchRecentEvents({int limit = 100}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final rows = await supabase
        .from('coin_events')
        .select('id, kind, coins, asset, created_at, session_id, plan_date')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows.map(_fromRow).toList();
  }

  CoinEventEntry _fromRow(Map<String, dynamic> e) {
    return CoinEventEntry(
      id: e['id'] as String,
      kind: e['kind'] as String,
      coins: ((e['coins'] ?? 0) as num).toInt(),
      asset: e['asset'] as String? ?? 'block',
      createdAt:
          DateTime.tryParse(e['created_at'] as String? ?? '') ?? DateTime.now(),
      sessionId: e['session_id'] as String?,
      planDate: e['plan_date'] != null
          ? DateTime.tryParse(e['plan_date'].toString())?.toUtc()
          : null,
    );
  }

  static String kindLabelKo(String kind) {
    switch (kind) {
      case 'focused_time':
        return '집중 공부';
      case 'plan_80_bonus':
        return '계획 달성 보너스';
      case 'streak_bonus_50':
        return '연속 달성 보너스';
      case 'gacha_spend':
        return '뽑기 사용';
      case 'gacha_refund':
        return '뽑기 환불';
      case 'supporter_block_out':
        return '서포터 교환 (블럭 차감)';
      case 'supporter_redeem_in':
        return '서포터 교환 (코인 지급)';
      default:
        return kind;
    }
  }

  static String assetUnitKo(String asset) =>
      asset == 'redeem_coin' ? '코인' : '블럭';

  /// ±N 블럭 / ±N 코인
  static String formatSignedAmount(CoinEventEntry e) {
    final unit = assetUnitKo(e.asset);
    final n = e.coins;
    final sign = n > 0 ? '+' : '';
    return '$sign$n $unit';
  }
}
