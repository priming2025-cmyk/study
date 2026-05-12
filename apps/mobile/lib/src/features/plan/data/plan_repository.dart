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

  /// FK(profiles) 때문에 계획 insert가 실패하는 경우를 막기 위해, 본인 프로필 행을 보장합니다.
  /// Supabase에 `profiles_insert_own` RLS가 있어야 합니다.
  /// (저장소 루트에서 `npm run db:push` 또는 SQL Editor로 `supabase/sql/0011_profiles_insert_own.sql`·`과목추가_필수수정.sql` 적용)
  Future<void> ensureProfileRow() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');
    try {
      await supabase.from('profiles').upsert(
        {'id': userId, 'role': 'student'},
        onConflict: 'id',
      );
    } catch (e) {
      throw Exception(
        '프로필을 만들 수 없어 계획을 저장하지 못했어요. '
        '저장소 루트에서 `npm run db:supabase-login` 후 `npm run db:push` 하거나, '
        'SQL Editor에서 `supabase/sql/0011_profiles_insert_own.sql`(또는 과목추가_필수수정.sql)을 실행한 뒤 다시 시도해 주세요. '
        '(원인: $e)',
      );
    }
  }

  /// 네트워크 없이 바로 보여 줄 마지막 저장본(모바일만).
  Future<TodayPlan?> loadCachedTodayPlan() =>
      loadCachedPlanForDate(DateTime.now());

  Future<TodayPlan?> loadCachedPlanForDate(DateTime planDay) async {
    final userId = supabase.auth.currentUser?.id;
    final cache = _cache;
    if (userId == null || cache == null) return null;
    return cache.load(userId, _toDateString(planDay));
  }

  Future<void> saveTodayPlanToCache(TodayPlan plan) =>
      savePlanToCacheForDate(DateTime.now(), plan);

  Future<void> savePlanToCacheForDate(DateTime planDay, TodayPlan plan) async {
    final userId = supabase.auth.currentUser?.id;
    final cache = _cache;
    if (userId == null || cache == null) return;
    await cache.save(userId, _toDateString(planDay), plan);
  }

  Future<TodayPlan?> fetchTodayPlan() => fetchPlanForDate(DateTime.now());

  Future<TodayPlan?> fetchPlanForDate(DateTime planDay) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final planDate = _toDateString(planDay);

    try {
      final remote = await _fetchPlanRemote(userId, planDate);
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

  Future<TodayPlan?> _fetchPlanRemote(String userId, String planDate) async {
    final plans = await supabase
        .from('plans')
        .select('id, plan_date, title')
        .eq('user_id', userId)
        .eq('plan_date', planDate)
        .limit(1);

    if (plans.isEmpty) return null;
    final plan = plans.first;
    final planId = plan['id'] as String;

    late final List<dynamic> itemsRaw;
    try {
      itemsRaw = await supabase
          .from('plan_items')
          .select(
            'id, subject, target_seconds, actual_seconds, is_done, scheduled_start_at, reminder_enabled',
          )
          .eq('plan_id', planId)
          .order('created_at', ascending: true);
    } catch (_) {
      try {
        itemsRaw = await supabase
            .from('plan_items')
            .select('id, subject, target_seconds, actual_seconds, is_done')
            .eq('plan_id', planId)
            .order('created_at', ascending: true);
      } catch (_) {
        itemsRaw = await supabase
            .from('plan_items')
            .select('id, subject, target_seconds')
            .eq('plan_id', planId)
            .order('created_at', ascending: true);
      }
    }

    final items = itemsRaw.map(_planItemFromRow).toList();

    return TodayPlan(
      id: planId,
      date: DateTime.parse('$planDate 00:00:00'),
      title: plan['title'] as String?,
      items: items,
    );
  }

  static PlanItem _planItemFromRow(dynamic e) {
    final m = e as Map<String, dynamic>;
    DateTime? scheduled;
    final rawSched = m['scheduled_start_at'];
    if (rawSched is String && rawSched.isNotEmpty) {
      scheduled = DateTime.tryParse(rawSched);
    }
    return PlanItem(
      id: m['id'] as String,
      subject: m['subject'] as String,
      targetSeconds: (m['target_seconds'] as num).toInt(),
      actualSeconds: ((m['actual_seconds'] ?? 0) as num).toInt(),
      isDone: (m['is_done'] ?? false) as bool,
      scheduledStartAt: scheduled,
      reminderEnabled: (m['reminder_enabled'] ?? false) as bool,
    );
  }

  Future<String> createOrUpdateTodayPlan({String? title}) =>
      createOrUpdatePlanForDate(DateTime.now(), title: title);

  Future<String> createOrUpdatePlanForDate(
    DateTime planDay, {
    String? title,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');
    await ensureProfileRow();

    final planDate = _toDateString(planDay);
    try {
      final plan = await supabase
          .from('plans')
          .upsert(
            {'user_id': userId, 'plan_date': planDate, 'title': title},
            onConflict: 'user_id,plan_date',
          )
          .select('id')
          .single();
      return plan['id'] as String;
    } catch (_) {
      final rows = await supabase
          .from('plans')
          .select('id')
          .eq('user_id', userId)
          .eq('plan_date', planDate)
          .limit(1);
      if (rows.isEmpty) rethrow;
      final dynamic m = rows.first;
      if (m is! Map) rethrow;
      return m['id'] as String;
    }
  }

  Future<PlanItem> addItem({
    required String planId,
    required String subject,
    required int targetSeconds,
    DateTime? scheduledStartAtUtc,
    bool reminderEnabled = false,
  }) async {
    await ensureProfileRow();

    final payloads = <Map<String, dynamic>>[
      if (scheduledStartAtUtc != null || reminderEnabled)
        {
          'plan_id': planId,
          'subject': subject,
          'target_seconds': targetSeconds,
          'priority': 0,
          if (scheduledStartAtUtc != null)
            'scheduled_start_at': scheduledStartAtUtc.toIso8601String(),
          'reminder_enabled': reminderEnabled,
        },
      {
        'plan_id': planId,
        'subject': subject,
        'target_seconds': targetSeconds,
        'priority': 0,
      },
      {
        'plan_id': planId,
        'subject': subject,
        'target_seconds': targetSeconds,
      },
    ];

    Object? lastErr;
    for (final row in payloads) {
      try {
        final inserted = await supabase
            .from('plan_items')
            .insert(row)
            .select('id, subject, target_seconds')
            .single();
        return PlanItem(
          id: inserted['id'] as String,
          subject: inserted['subject'] as String,
          targetSeconds: (inserted['target_seconds'] as num).toInt(),
          actualSeconds: 0,
          isDone: false,
          scheduledStartAt: scheduledStartAtUtc,
          reminderEnabled: reminderEnabled,
        );
      } catch (e) {
        lastErr = e;
        continue;
      }
    }
    if (lastErr != null) throw lastErr;
    throw Exception('plan_items insert failed');
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

    try {
      await supabase.from('plan_items').update(patch).eq('id', itemId);
    } catch (_) {
      final fallback = <String, dynamic>{};
      if (patch.containsKey('target_seconds')) {
        fallback['target_seconds'] = patch['target_seconds'];
      }
      if (fallback.isEmpty) rethrow;
      await supabase.from('plan_items').update(fallback).eq('id', itemId);
    }
  }

  /// 과목명·목표·시작 시각·알림을 한 번에 갱신(계획 편집 시트 저장용).
  Future<void> updatePlanItemDetails({
    required String itemId,
    required String subject,
    required int targetSeconds,
    DateTime? scheduledStartAtUtc,
    required bool reminderEnabled,
  }) async {
    final patch = <String, dynamic>{
      'subject': subject,
      'target_seconds': targetSeconds,
      'scheduled_start_at': scheduledStartAtUtc?.toIso8601String(),
      'reminder_enabled': reminderEnabled && scheduledStartAtUtc != null,
    };
    try {
      await supabase.from('plan_items').update(patch).eq('id', itemId);
    } catch (_) {
      await supabase.from('plan_items').update({
        'subject': subject,
        'target_seconds': targetSeconds,
      }).eq('id', itemId);
    }
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
