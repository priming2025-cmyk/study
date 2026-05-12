import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/plan_models.dart';
import '../data/plan_repository.dart';
import '../infra/plan_alarm_service.dart';

class PlanEditorController extends ChangeNotifier {
  final PlanRepository _repo;
  final titleController = TextEditingController();

  DateTime _planDay = _calendarOnly(DateTime.now());
  int targetMinutes = 50;
  bool loading = true;
  bool savingTitle = false;
  TodayPlan? todayPlan;
  List<String> recentSubjects = const [];
  bool showingOfflinePlan = false;
  String? lastBootstrapError;

  PlanEditorController({PlanRepository? repo}) : _repo = repo ?? PlanRepository();

  static DateTime _calendarOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 현재 편집 중인 날짜(자정 기준).
  DateTime get planDay => _planDay;

  Future<void> setPlanDayAndReload(DateTime d) async {
    _planDay = _calendarOnly(d);
    await bootstrap();
  }

  Future<void> bootstrap() async {
    loading = true;
    showingOfflinePlan = false;
    lastBootstrapError = null;
    notifyListeners();

    try {
      final cached = await _repo.loadCachedPlanForDate(planDay);
      if (cached != null) {
        todayPlan = cached;
        titleController.text = cached.title ?? '';
        showingOfflinePlan = true;
        notifyListeners();
      }

      try {
        final fresh = await _repo.fetchPlanForDate(planDay);
        todayPlan = fresh;
        titleController.text = fresh?.title ?? '';
        showingOfflinePlan = false;

        try {
          recentSubjects = await _repo.fetchRecentSubjects();
        } catch (_) {
          recentSubjects = recentSubjects;
        }
        await PlanAlarmService.syncFromPlan(todayPlan);
      } catch (e) {
        if (todayPlan == null) {
          lastBootstrapError = e.toString();
        } else {
          showingOfflinePlan = true;
        }
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _persistCache() async {
    final p = todayPlan;
    if (p == null) return;
    await _repo.savePlanToCacheForDate(planDay, p);
  }

  Future<String> ensurePlanId() async {
    final existing = todayPlan;
    if (existing != null) return existing.id;
    await _repo.ensureProfileRow();
    final id = await _repo.createOrUpdatePlanForDate(
      planDay,
      title: titleController.text.trim().isEmpty
          ? null
          : titleController.text.trim(),
    );
    todayPlan = await _repo.fetchPlanForDate(planDay);
    todayPlan ??= TodayPlan(id: id, date: planDay, title: null, items: const []);
    await _persistCache();
    await PlanAlarmService.syncFromPlan(todayPlan);
    showingOfflinePlan = false;
    notifyListeners();
    return id;
  }

  Future<void> saveTitle() async {
    savingTitle = true;
    notifyListeners();
    try {
      await _repo.createOrUpdatePlanForDate(
        planDay,
        title: titleController.text.trim().isEmpty
            ? null
            : titleController.text.trim(),
      );
      todayPlan = await _repo.fetchPlanForDate(planDay);
      await _persistCache();
      showingOfflinePlan = false;
      await PlanAlarmService.syncFromPlan(todayPlan);
    } finally {
      savingTitle = false;
      notifyListeners();
    }
  }

  /// 과목 추가(바텀시트에서 호출). 시작 시각 + 로컬 알림 옵션 포함.
  Future<void> addPlanEntry({
    required String subject,
    required int targetMinutes,
    TimeOfDay? startTime,
    required bool reminderEnabled,
  }) async {
    final trimmed = subject.trim();
    if (trimmed.isEmpty) return;

    DateTime? scheduledUtc;
    if (startTime != null) {
      final local = DateTime(
        planDay.year,
        planDay.month,
        planDay.day,
        startTime.hour,
        startTime.minute,
      );
      scheduledUtc = local.toUtc();
    }

    final planId = await ensurePlanId();
    final item = await _repo.addItem(
      planId: planId,
      subject: trimmed,
      targetSeconds: targetMinutes * 60,
      scheduledStartAtUtc: scheduledUtc,
      reminderEnabled: reminderEnabled && scheduledUtc != null,
    );

    final plan = todayPlan;
    todayPlan = TodayPlan(
      id: planId,
      date: planDay,
      title: plan?.title,
      items: [...(plan?.items ?? const []), item],
    );
    await _persistCache();
    showingOfflinePlan = false;
    await PlanAlarmService.syncFromPlan(todayPlan);
    notifyListeners();
  }

  /// 기존 항목의 과목·목표 시간·시작 시각·알림 수정.
  Future<void> updatePlanEntry({
    required PlanItem item,
    required String subject,
    required int targetMinutes,
    TimeOfDay? startTime,
    required bool reminderEnabled,
  }) async {
    final trimmed = subject.trim();
    if (trimmed.isEmpty) return;
    final clampedMin = targetMinutes.clamp(1, 960);

    DateTime? scheduledUtc;
    if (startTime != null) {
      final local = DateTime(
        planDay.year,
        planDay.month,
        planDay.day,
        startTime.hour,
        startTime.minute,
      );
      scheduledUtc = local.toUtc();
    }

    await _repo.updatePlanItemDetails(
      itemId: item.id,
      subject: trimmed,
      targetSeconds: clampedMin * 60,
      scheduledStartAtUtc: scheduledUtc,
      reminderEnabled: reminderEnabled,
    );

    todayPlan = await _repo.fetchPlanForDate(planDay);
    await _persistCache();
    showingOfflinePlan = false;
    try {
      recentSubjects = await _repo.fetchRecentSubjects();
    } catch (_) {}
    await PlanAlarmService.syncFromPlan(todayPlan);
    notifyListeners();
  }

  Future<void> deleteItem(PlanItem item) async {
    await PlanAlarmService.cancel(item.id);
    await _repo.deleteItem(item.id);
    final plan = todayPlan;
    if (plan == null) return;
    todayPlan = TodayPlan(
      id: plan.id,
      date: plan.date,
      title: plan.title,
      items: plan.items.where((e) => e.id != item.id).toList(),
    );
    await _persistCache();
    await PlanAlarmService.syncFromPlan(todayPlan);
    notifyListeners();
  }

  Future<void> toggleDone(PlanItem item, bool done) async {
    await _repo.updateItem(itemId: item.id, isDone: done);
    final plan = todayPlan;
    if (plan == null) return;
    todayPlan = TodayPlan(
      id: plan.id,
      date: plan.date,
      title: plan.title,
      items: plan.items
          .map(
            (e) => e.id == item.id
                ? e.copyWith(isDone: done)
                : e,
          )
          .toList(),
    );
    await _persistCache();
    notifyListeners();
  }

  Future<void> setActualMinutes(PlanItem item, int minutes) async {
    final seconds = (minutes * 60).clamp(0, 24 * 3600);
    await _repo.updateItem(itemId: item.id, actualSeconds: seconds);
    final plan = todayPlan;
    if (plan == null) return;
    todayPlan = TodayPlan(
      id: plan.id,
      date: plan.date,
      title: plan.title,
      items: plan.items
          .map(
            (e) => e.id == item.id
                ? e.copyWith(actualSeconds: seconds)
                : e,
          )
          .toList(),
    );
    await _persistCache();
    notifyListeners();
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  AuthException authError() => const AuthException('Not authenticated');
}
