import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/plan_models.dart';
import '../data/plan_repository.dart';

class PlanEditorController extends ChangeNotifier {
  final PlanRepository _repo;
  final titleController = TextEditingController();
  final subjectController = TextEditingController();

  int targetMinutes = 50;
  bool loading = true;
  bool savingTitle = false;
  TodayPlan? todayPlan;
  List<String> recentSubjects = const [];
  /// 서버 대신(또는 먼저) 로컬 저장본을 보고 있을 때 안내용.
  bool showingOfflinePlan = false;
  String? lastBootstrapError;

  PlanEditorController({PlanRepository? repo}) : _repo = repo ?? PlanRepository();

  Future<void> bootstrap() async {
    loading = true;
    showingOfflinePlan = false;
    lastBootstrapError = null;
    notifyListeners();

    try {
      final cached = await _repo.loadCachedTodayPlan();
      if (cached != null) {
        todayPlan = cached;
        titleController.text = cached.title ?? '';
        showingOfflinePlan = true;
        notifyListeners();
      }

      try {
        final fresh = await _repo.fetchTodayPlan();
        todayPlan = fresh;
        titleController.text = fresh?.title ?? '';
        showingOfflinePlan = false;

        try {
          recentSubjects = await _repo.fetchRecentSubjects();
        } catch (_) {
          recentSubjects = recentSubjects;
        }
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
    await _repo.saveTodayPlanToCache(p);
  }

  Future<String> ensurePlanId() async {
    final existing = todayPlan;
    if (existing != null) return existing.id;
    final id = await _repo.createOrUpdateTodayPlan(
      title: titleController.text.trim().isEmpty ? null : titleController.text.trim(),
    );
    todayPlan = await _repo.fetchTodayPlan();
    await _persistCache();
    notifyListeners();
    return id;
  }

  Future<void> saveTitle() async {
    savingTitle = true;
    notifyListeners();
    try {
      await _repo.createOrUpdateTodayPlan(
        title: titleController.text.trim().isEmpty ? null : titleController.text.trim(),
      );
      todayPlan = await _repo.fetchTodayPlan();
      await _persistCache();
      showingOfflinePlan = false;
    } finally {
      savingTitle = false;
      notifyListeners();
    }
  }

  Future<void> addItem({String? subjectOverride}) async {
    final subject = (subjectOverride ?? subjectController.text).trim();
    if (subject.isEmpty) return;

    final planId = await ensurePlanId();
    final item = await _repo.addItem(
      planId: planId,
      subject: subject,
      targetSeconds: targetMinutes * 60,
    );

    subjectController.clear();
    final plan = todayPlan;
    todayPlan = TodayPlan(
      id: planId,
      date: DateTime.now(),
      title: plan?.title,
      items: [...(plan?.items ?? const []), item],
    );
    await _persistCache();
    showingOfflinePlan = false;
    notifyListeners();
  }

  Future<void> deleteItem(PlanItem item) async {
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
          .map((e) => e.id == item.id
              ? PlanItem(
                  id: e.id,
                  subject: e.subject,
                  targetSeconds: e.targetSeconds,
                  actualSeconds: e.actualSeconds,
                  isDone: done,
                )
              : e)
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
          .map((e) => e.id == item.id
              ? PlanItem(
                  id: e.id,
                  subject: e.subject,
                  targetSeconds: e.targetSeconds,
                  actualSeconds: seconds,
                  isDone: e.isDone,
                )
              : e)
          .toList(),
    );
    await _persistCache();
    notifyListeners();
  }

  @override
  void dispose() {
    titleController.dispose();
    subjectController.dispose();
    super.dispose();
  }

  AuthException authError() => const AuthException('Not authenticated');
}
