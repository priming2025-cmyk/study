import '../../../core/local_db/app_database.dart';
import 'plan_models.dart';
import 'plan_today_codec.dart';

/// 기기 로컬에 오늘 계획만 잠깐 저장해 빠르게 보여 주고, 끊김 시에도 볼 수 있게 합니다.
final class PlanTodayLocalCache {
  PlanTodayLocalCache(this._db);

  final AppDatabase _db;

  static String rowId(String userId, String planDate) => '$userId::$planDate';

  Future<void> save(String userId, String planDate, TodayPlan plan) async {
    await _db.upsertLocalPlan(
      id: rowId(userId, planDate),
      itemsJson: TodayPlanCodec.toJsonString(plan),
      title: plan.title,
    );
  }

  Future<TodayPlan?> load(String userId, String planDate) async {
    final id = rowId(userId, planDate);
    final row = await (_db.select(_db.localPlans)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return TodayPlanCodec.fromJsonString(row.itemsJson);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String userId, String planDate) async {
    final id = rowId(userId, planDate);
    await (_db.delete(_db.localPlans)..where((t) => t.id.equals(id))).go();
  }
}
