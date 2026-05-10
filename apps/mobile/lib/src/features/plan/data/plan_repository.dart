import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/supabase/supabase_client.dart';
import 'plan_local_cache.dart';
import 'plan_models.dart';

class PlanRepository {
  PlanRepository({AppDatabase? database})
      : _cache = database != null ? PlanTodayLocalCache(database) : null;

  final PlanTodayLocalCache? _cache;

  bool get hasLocalCache => _cache != null;

  String _toDateString(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .toIso8601String()
        .substring(0, 10);
  }

  /// 네트워크 없이 바로 보여 줄 마지막 저장본(모바일만).
  Future<TodayPlan?> loadCachedTodayPlan() async {
    final userId = supabase.auth.currentUser?.id;
    final cache = _cache;
    if (userId == null || cache == null) return null;
    return cache.load(userId, _toDateString(DateTime.now()));
  }

  /// 화면에서 목록을 바꾼 뒤 로컬과 맞춰 둡니다.
  Future<void> saveTodayPlanToCache(TodayPlan plan) async {
    final userId = supabase.auth.currentUser?.id;
    final cache = _cache;
    if (userId == null || cache == null) return;
    await cache.save(userId, _toDateString(DateTime.now()), plan);
  }

  Future<TodayPlan?> fetchTodayPlan() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final planDate = _toDateString(DateTime.now());

    try {
      final remote = await _fetchTodayPlanRemote(userId, planDate);
      final cache = _cache;
      if (cache != null) {
        if (remote == null) {
          await cache.clear(userId, planDate);
        } else {
          await cache.save(userId, planDate, remote);
        }
      }
      return remote;
    } catch (_) {
      final cache = _cache;
      if (cache != null) {
        final cached = await cache.load(userId, planDate);
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  Future<TodayPlan?> _fetchTodayPlanRemote(String userId, String planDate) async {
    final plans = await supabase
        .from('plans')
        .select('id, plan_date, title')
        .eq('user_id', userId)
        .eq('plan_date', planDate)
        .limit(1);

    if (plans.isEmpty) return null;
    final plan = plans.first;
    final planId = plan['id'] as String;

    final itemsRaw = await supabase
        .from('plan_items')
        .select('id, subject, target_seconds, actual_seconds, is_done')
        .eq('plan_id', planId)
        .order('created_at', ascending: true);

    final items = itemsRaw
        .map(
          (e) => PlanItem(
            id: e['id'] as String,
            subject: e['subject'] as String,
            targetSeconds: (e['target_seconds'] as num).toInt(),
            actualSeconds: ((e['actual_seconds'] ?? 0) as num).toInt(),
            isDone: (e['is_done'] ?? false) as bool,
          ),
        )
        .toList();

    return TodayPlan(
      id: planId,
      date: DateTime.now(),
      title: plan['title'] as String?,
      items: items,
    );
  }

  Future<String> createOrUpdateTodayPlan({String? title}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final planDate = _toDateString(DateTime.now());
    final plan = await supabase
        .from('plans')
        .upsert(
          {'user_id': userId, 'plan_date': planDate, 'title': title},
          onConflict: 'user_id,plan_date',
        )
        .select('id')
        .single();
    return plan['id'] as String;
  }

  Future<PlanItem> addItem({
    required String planId,
    required String subject,
    required int targetSeconds,
  }) async {
    final inserted = await supabase
        .from('plan_items')
        .insert({
          'plan_id': planId,
          'subject': subject,
          'target_seconds': targetSeconds,
          'priority': 0,
        })
        .select('id, subject, target_seconds, actual_seconds, is_done')
        .single();

    return PlanItem(
      id: inserted['id'] as String,
      subject: inserted['subject'] as String,
      targetSeconds: (inserted['target_seconds'] as num).toInt(),
      actualSeconds: ((inserted['actual_seconds'] ?? 0) as num).toInt(),
      isDone: (inserted['is_done'] ?? false) as bool,
    );
  }

  Future<void> updateItem({
    required String itemId,
    int? targetSeconds,
    int? actualSeconds,
    bool? isDone,
  }) async {
    final patch = <String, dynamic>{};
    if (targetSeconds != null) patch['target_seconds'] = targetSeconds;
    if (actualSeconds != null) patch['actual_seconds'] = actualSeconds;
    if (isDone != null) patch['is_done'] = isDone;
    if (patch.isEmpty) return;

    await supabase.from('plan_items').update(patch).eq('id', itemId);
  }

  Future<void> deleteItem(String itemId) async {
    await supabase.from('plan_items').delete().eq('id', itemId);
  }

  Future<List<String>> fetchRecentSubjects({int limit = 12}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final raw = await supabase
        .from('plan_items')
        .select('subject, plans!inner(user_id)')
        .eq('plans.user_id', userId)
        .order('created_at', ascending: false)
        .limit(80);

    final set = <String>{};
    for (final e in raw) {
      final s = (e['subject'] as String).trim();
      if (s.isEmpty) continue;
      set.add(s);
      if (set.length >= limit) break;
    }
    return set.toList();
  }
}
