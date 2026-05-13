import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../stats/data/daily_focus_stat.dart';
import '../domain/session_summary.dart';
import '../domain/wallet_balances.dart';

class SessionRepository {
  const SessionRepository();

  Future<String> uploadSummary(SessionSummary summary) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    String validationState;
    switch (summary.validationState) {
      case ValidationState.ok:
        validationState = 'OK';
        break;
      case ValidationState.uncertain:
        validationState = 'UNCERTAIN';
        break;
      case ValidationState.failed:
        validationState = 'FAILED';
        break;
    }

    final inserted = await supabase.from('study_sessions').insert({
      'user_id': userId,
      'started_at': summary.startedAt.toUtc().toIso8601String(),
      'ended_at': summary.endedAt?.toUtc().toIso8601String(),
      'subject': summary.subject,
      'plan_item_id': summary.planItemId,
      'focused_seconds': summary.focusedSeconds,
      'unfocused_seconds': summary.unfocusedSeconds,
      'validation_state': validationState,
      'pause_count': summary.pauseCount,
      'app_background_count': summary.appBackgroundCount,
      'face_missing_events': summary.faceMissingEvents,
      'multi_face_events': summary.multiFaceEvents,
      'device_tz': DateTime.now().timeZoneName,
    }).select('id').single();

    return inserted['id'] as String;
  }

  /// Apply focused seconds to a plan item (auto progress).
  Future<void> applyFocusedToPlanItem({
    required String planItemId,
    required int focusedSeconds,
  }) async {
    if (focusedSeconds <= 0) return;
    // Increment in DB to avoid race with multiple sessions.
    await supabase.rpc(
      'increment_plan_item_actual_seconds',
      params: {'p_item_id': planItemId, 'p_delta': focusedSeconds},
    );
  }

  Future<int> fetchTodayFocusedSeconds() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final now = DateTime.now();
    final startLocal = DateTime(now.year, now.month, now.day);
    final endLocal = startLocal.add(const Duration(days: 1));

    final rows = await supabase
        .from('study_sessions')
        .select('focused_seconds, started_at')
        .eq('user_id', userId)
        .gte('started_at', startLocal.toUtc().toIso8601String())
        .lt('started_at', endLocal.toUtc().toIso8601String());

    int sum = 0;
    for (final r in rows) {
      sum += ((r['focused_seconds'] ?? 0) as num).toInt();
    }
    return sum;
  }

  /// XP·레벨·스트릭·칭호 해금 (세션당 1회, idempotent).
  Future<Map<String, dynamic>> applySessionProgress({
    required String sessionId,
    required int focusedSeconds,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final res = await supabase.rpc(
      'apply_session_progress',
      params: {
        'p_user_id': userId,
        'p_session_id': sessionId,
        'p_focused_seconds': focusedSeconds,
      },
    );
    return Map<String, dynamic>.from(res as Map);
  }

  /// 스쿼드 주간 미션에 집중 시간 반영 (세션당 1회).
  Future<void> applySquadSessionContribution({
    required String sessionId,
    required int focusedSeconds,
  }) async {
    if (supabase.auth.currentUser?.id == null) {
      throw const AuthException('Not authenticated');
    }
    await supabase.rpc(
      'apply_squad_session_contribution',
      params: {
        'p_session_id': sessionId,
        'p_focused_seconds': focusedSeconds,
      },
    );
  }

  Future<int> awardCoinsForSession({
    required String sessionId,
    required int focusedSeconds,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final coins = await supabase.rpc(
      'award_coins_for_session',
      params: {
        'p_user_id': userId,
        'p_session_id': sessionId,
        'p_focused_seconds': focusedSeconds,
      },
    );
    return (coins as num).toInt();
  }

  /// 블럭 + 교환 코인 잔고.
  Future<WalletBalances> fetchWalletBalances() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final row = await supabase
        .from('coin_balances')
        .select('block_balance, redeem_coin_balance')
        .eq('user_id', userId)
        .maybeSingle();

    return WalletBalances.fromRow(row);
  }

  Future<int> awardPlanBonusForToday() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final coins = await supabase.rpc(
      'award_plan_bonus_for_today',
      params: {'p_user_id': userId},
    );
    return (coins as num).toInt();
  }

  Future<int> awardStreakBonusForToday() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final coins = await supabase.rpc(
      'award_streak_bonus_for_today',
      params: {'p_user_id': userId},
    );
    return (coins as num).toInt();
  }

  /// 기기 로컬 날짜 기준 최근 [days]일, 세션 `started_at`이 속한 날에 집중 초를 합산합니다.
  Future<List<DailyFocusStat>> fetchDailyFocusLastDays(int days) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');
    if (days < 1) return const [];

    final now = DateTime.now();
    final startLocal =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final startUtc = startLocal.toUtc();

    final rows = await supabase
        .from('study_sessions')
        .select('started_at, focused_seconds')
        .eq('user_id', userId)
        .gte('started_at', startUtc.toIso8601String());

    final map = <DateTime, int>{};
    for (var i = 0; i < days; i++) {
      final d = startLocal.add(Duration(days: i));
      map[DateTime(d.year, d.month, d.day)] = 0;
    }
    for (final r in rows) {
      final t = DateTime.parse(r['started_at'] as String).toLocal();
      final key = DateTime(t.year, t.month, t.day);
      map[key] =
          (map[key] ?? 0) + ((r['focused_seconds'] ?? 0) as num).toInt();
    }

    final list = map.entries
        .map((e) => DailyFocusStat(dayLocal: e.key, focusedSeconds: e.value))
        .toList()
      ..sort((a, b) => a.dayLocal.compareTo(b.dayLocal));
    return list;
  }
}

