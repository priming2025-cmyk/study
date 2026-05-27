import 'plan_alarm_stub.dart'
    if (dart.library.html) 'plan_alarm_web.dart'
    if (dart.library.io) 'plan_alarm_io.dart' as impl;

import '../data/plan_models.dart';

/// 계획 항목의 시작 시각 로컬 알림(웹은 브라우저 알림 + 타이머).
abstract final class PlanAlarmService {
  static Future<void> init() => impl.planAlarmInit();

  static Future<void> schedulePlanStart({
    required String planItemId,
    required String subject,
    required DateTime whenLocal,
  }) =>
      impl.planAlarmSchedule(
        planItemId: planItemId,
        subject: subject,
        whenLocal: whenLocal,
        fiveMinBefore: false,
      );

  static Future<void> schedulePlanFiveMinBefore({
    required String planItemId,
    required String subject,
    required DateTime whenLocal,
  }) =>
      impl.planAlarmSchedule(
        planItemId: planItemId,
        subject: subject,
        whenLocal: whenLocal,
        fiveMinBefore: true,
      );

  static Future<void> cancel(String planItemId) =>
      impl.planAlarmCancel(planItemId);

  static Future<void> syncFromPlan(TodayPlan? plan) async {
    await init();
    for (final item in plan?.items ?? const <PlanItem>[]) {
      await cancel(item.id);
    }
    if (plan == null) return;
    final now = DateTime.now();
    for (final item in plan.items) {
      if (!item.reminderEnabled || item.scheduledStartAt == null) continue;
      final local = item.scheduledStartAt!.toLocal();
      final fiveMinBefore = local.subtract(const Duration(minutes: 5));
      if (fiveMinBefore.isAfter(now)) {
        await schedulePlanFiveMinBefore(
          planItemId: item.id,
          subject: item.subject,
          whenLocal: fiveMinBefore,
        );
      }
      if (local.isAfter(now)) {
        await schedulePlanStart(
          planItemId: item.id,
          subject: item.subject,
          whenLocal: local,
        );
      }
    }
  }
}
