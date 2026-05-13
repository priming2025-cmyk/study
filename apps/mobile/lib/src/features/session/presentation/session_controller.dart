import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../plan/data/plan_models.dart';
import '../../plan/data/plan_repository.dart';
import '../../plan/infra/plan_alarm_service.dart';
import '../data/session_repository.dart';
import '../domain/attention_scoring.dart';
import '../domain/attention_signals.dart';
import '../domain/engaged_time_threshold.dart';
import '../domain/session_summary.dart';
import '../domain/session_reward_result.dart';
import '../infra/face_attention_sensor.dart';
import '../infra/session_camera_cache.dart';
import '../infra/study_presence.dart';

class SessionController extends ChangeNotifier {
  final PlanRepository _planRepo;
  final SessionRepository _sessionRepo;
  final FaceAttentionSensor _sensor;
  final StudyPresence _presence;

  Timer? _timer;
  StreamSubscription<AttentionSignals>? _sub;
  StreamSubscription<List<PresenceMember>>? _presenceSub;

  bool running = false;
  bool starting = false;
  bool loadingPlan = true;

  AttentionScoringState? state;
  AttentionSignals signals = const AttentionSignals(
    facePresent: true,
    multiFace: false,
    appInForeground: true,
  );

  TodayPlan? todayPlan;
  String? selectedPlanItemId;
  String selectedSubjectLabel = '';
  List<String> recentSubjects = const [];

  List<PresenceMember> others = const [];

  CameraDescription? frontCamera;
  bool appInForeground = true;

  /// 집중 초 누적 기준: 즉시 점수 ≥ 이 값 (80·65·50·35·20 중 선택, 기본 50).
  int _engagedMinScore = kDefaultEngagedMinScore;

  int get engagedMinScore => _engagedMinScore;

  SessionController({
    PlanRepository? planRepo,
    SessionRepository? sessionRepo,
    FaceAttentionSensor? sensor,
    StudyPresence? presence,
  })  : _planRepo = planRepo ?? PlanRepository(),
        _sessionRepo = sessionRepo ?? const SessionRepository(),
        _sensor = sensor ?? FaceAttentionSensor(),
        _presence = presence ?? StudyPresence();

  CameraController? get cameraController => _sensor.controller;

  /// 웹: [SessionSelfCameraSurface] 위젯이 `<video>` 프레임을 분석해 호출합니다.
  /// (웹은 FaceAttentionSensor를 시작하지 않고 이 경로만 씁니다.)
  void applyWebAttentionSignals(AttentionSignals s) {
    signals = s;
    notifyListeners();
  }

  Future<void> init() async {
    _engagedMinScore = await loadEngagedMinScore();
    notifyListeners();
    await _loadTodayPlan();
  }

  /// 집중 시간 기준(5단계). 세션 중에도 다음 틱부터 반영.
  Future<void> setEngagedMinScore(int value) async {
    _engagedMinScore = normalizeEngagedMinScore(value);
    await saveEngagedMinScore(_engagedMinScore);
    notifyListeners();
  }

  /// 미완(완료 아님 & 목표 미달) 항목 중 첫 번째, 없으면 첫 항목.
  static PlanItem? pickDefaultIncompleteItem(TodayPlan? plan) {
    if (plan == null || plan.items.isEmpty) return null;
    for (final item in plan.items) {
      if (!item.isDone && item.actualSeconds < item.targetSeconds) {
        return item;
      }
    }
    return plan.items.first;
  }

  void _applyDefaultPlanSelection(TodayPlan? plan) {
    final pick = pickDefaultIncompleteItem(plan);
    if (pick != null) {
      selectedPlanItemId = pick.id;
      selectedSubjectLabel = pick.subject;
    } else {
      selectedPlanItemId = null;
      selectedSubjectLabel = '';
    }
  }

  Future<void> _loadTodayPlan() async {
    try {
      final cached = await _planRepo.loadCachedTodayPlan();
      if (cached != null) {
        todayPlan = cached;
        _applyDefaultPlanSelection(cached);
        notifyListeners();
      }
      todayPlan = await _planRepo.fetchTodayPlan();
      if (todayPlan != null && todayPlan!.items.isNotEmpty) {
        _applyDefaultPlanSelection(todayPlan);
      }
      try {
        recentSubjects = await _planRepo.fetchRecentSubjects();
      } catch (_) {
        recentSubjects = const [];
      }
    } finally {
      loadingPlan = false;
      notifyListeners();
    }
  }

  void selectPlanItem(PlanItem item) {
    selectedPlanItemId = item.id;
    selectedSubjectLabel = item.subject;
    notifyListeners();
  }

  /// 오늘 계획에 항목을 추가하고 바로 집중할 과목으로 선택합니다. (계획 편집과 동일한 저장 규칙)
  Future<void> addItemAndSelect({
    required String subject,
    required int targetMinutes,
    TimeOfDay? startTime,
    bool reminderEnabled = false,
  }) async {
    final trimmed = subject.trim();
    if (trimmed.isEmpty) return;
    final clampedMin = targetMinutes.clamp(1, 960);

    final today = DateTime.now();
    DateTime? scheduledUtc;
    if (startTime != null) {
      final local = DateTime(
        today.year,
        today.month,
        today.day,
        startTime.hour,
        startTime.minute,
      );
      scheduledUtc = local.toUtc();
    }

    final planId = await _planRepo.createOrUpdateTodayPlan();
    final item = await _planRepo.addItem(
      planId: planId,
      subject: trimmed,
      targetSeconds: clampedMin * 60,
      scheduledStartAtUtc: scheduledUtc,
      reminderEnabled: reminderEnabled && scheduledUtc != null,
    );
    todayPlan = await _planRepo.fetchTodayPlan();
    selectPlanItem(item);
    try {
      recentSubjects = await _planRepo.fetchRecentSubjects();
    } catch (_) {
      recentSubjects = const [];
    }
    await PlanAlarmService.syncFromPlan(todayPlan);
    notifyListeners();
  }

  /// 오늘 계획 항목 수정(집중 세션에서 연필 시트와 동일 규칙).
  Future<void> updatePlanItem({
    required PlanItem item,
    required String subject,
    required int targetMinutes,
    TimeOfDay? startTime,
    required bool reminderEnabled,
  }) async {
    final trimmed = subject.trim();
    if (trimmed.isEmpty) return;
    final clampedMin = targetMinutes.clamp(1, 960);

    final today = DateTime.now();
    final planDay = DateTime(today.year, today.month, today.day);
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

    await _planRepo.updatePlanItemDetails(
      itemId: item.id,
      subject: trimmed,
      targetSeconds: clampedMin * 60,
      scheduledStartAtUtc: scheduledUtc,
      reminderEnabled: reminderEnabled,
    );
    todayPlan = await _planRepo.fetchTodayPlan();
    if (selectedPlanItemId == item.id) {
      PlanItem? found;
      for (final e in todayPlan?.items ?? const <PlanItem>[]) {
        if (e.id == item.id) {
          found = e;
          break;
        }
      }
      if (found != null) {
        selectedSubjectLabel = found.subject;
      }
    }
    try {
      recentSubjects = await _planRepo.fetchRecentSubjects();
    } catch (_) {
      recentSubjects = const [];
    }
    await PlanAlarmService.syncFromPlan(todayPlan);
    notifyListeners();
  }

  /// 오늘 계획에서 항목 삭제. 선택 중이던 항목이면 다른 항목으로 옮깁니다.
  Future<void> deletePlanItem(PlanItem item) async {
    await PlanAlarmService.cancel(item.id);
    await _planRepo.deleteItem(item.id);
    todayPlan = await _planRepo.fetchTodayPlan();
    final wasSelected = selectedPlanItemId == item.id;
    if (wasSelected) {
      if (todayPlan != null && todayPlan!.items.isNotEmpty) {
        selectPlanItem(todayPlan!.items.first);
      } else {
        selectedPlanItemId = null;
        selectedSubjectLabel = '';
      }
    }
    try {
      recentSubjects = await _planRepo.fetchRecentSubjects();
    } catch (_) {
      recentSubjects = const [];
    }
    await PlanAlarmService.syncFromPlan(todayPlan);
    notifyListeners();
  }

  Future<void> start() async {
    if (running || starting) return;
    starting = true;
    notifyListeners();

    final subject = selectedSubjectLabel.trim();
    if (subject.isEmpty) {
      starting = false;
      notifyListeners();
      throw StateError('집중할 과목을 먼저 선택하거나 추가해 주세요.');
    }

    final now = DateTime.now();
    state = AttentionScoringState.started(now);
    running = true;
    starting = false;
    notifyListeners();

    // 타이머를 먼저 걸어, 카메라 초기화·Presence가 오래 걸려도 초·집중도가 멈추지 않게 합니다.
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!running) return;
      final s = state;
      if (s == null) return;
      state = AttentionScoring.tick(
        state: s,
        now: DateTime.now(),
        signals: signals,
        engagedMinScore: _engagedMinScore,
      );
      notifyListeners();
    });

    // 웹: 카메라·얼굴 분석은 SessionSelfCameraSurface(HtmlElementView)가 담당하므로
    // FaceAttentionSensor를 시작하지 않습니다. Presence만 비동기로 붙입니다.
    if (kIsWeb) {
      unawaited(_bootstrapPresenceOnly(subject: subject, startedAt: now));
    } else {
      unawaited(_bootstrapCameraAndPresence(subject: subject, startedAt: now));
    }
  }

  /// 네이티브: 전면 카메라·얼굴 센서만 붙입니다. [running]이 false면 중도 취소합니다.
  Future<void> _startNativeCameraSensor() async {
    if (kIsWeb) return;
    final cam = await SessionCameraCache.getFrontOrDefault();
    frontCamera = cam;
    if (!running) return;

    await _sub?.cancel();
    _sub = null;

    if (cam != null) {
      try {
        _sub = _sensor.stream.listen((s) {
          signals = s;
          notifyListeners();
        });
        await _sensor.start(
          camera: cam,
          appInForeground: () => appInForeground,
        );
      } catch (e, st) {
        debugPrint('SessionController: 센서 시작 실패 → $e\n$st');
        await _sub?.cancel();
        _sub = null;
        await _sensor.stop();
        signals = AttentionSignals(
          facePresent: false,
          multiFace: false,
          appInForeground: appInForeground,
        );
      }
    } else {
      signals = AttentionSignals(
        facePresent: false,
        multiFace: false,
        appInForeground: appInForeground,
      );
    }

    if (!running) {
      await _sub?.cancel();
      _sub = null;
      await _sensor.stop();
      return;
    }
    notifyListeners();
  }

  /// 스터디 탭 등으로 나갈 때 카메라 단일 점유를 위해 센서만 끕니다. 타이머·[running]·Presence는 유지합니다.
  Future<void> suspendCameraForShellNavigation() async {
    if (kIsWeb) return;
    await _sub?.cancel();
    _sub = null;
    await _sensor.stop();
    notifyListeners();
  }

  /// 공부 탭으로 돌아온 뒤 [running]이면 카메라를 다시 붙입니다.
  Future<void> resumeCameraAfterShellNavigation() async {
    if (kIsWeb || !running) return;
    await _startNativeCameraSensor();
  }

  /// [start] 직후 비동기로 실행. 메인 isolate를 길게 막지 않도록 분리합니다.
  Future<void> _bootstrapCameraAndPresence({
    required String subject,
    required DateTime startedAt,
  }) async {
    await _startNativeCameraSensor();
    if (!running) return;

    final selfId = supabase.auth.currentUser?.id;
    if (selfId != null && running) {
      try {
        await _presence.join(
          selfId: selfId,
          subject: subject,
          startedAt: startedAt,
        );
        if (!running) {
          await _presence.leave();
          return;
        }
        await _presenceSub?.cancel();
        _presenceSub = _presence.members.listen((list) {
          others = list.where((m) => m.userId != selfId).toList();
          notifyListeners();
        });
      } catch (e, st) {
        debugPrint('SessionController: Presence 실패(세션은 계속) → $e\n$st');
      }
    }
    if (running) notifyListeners();
  }

  /// 웹 전용: Presence만 비동기 연결합니다 (카메라·센서 없음).
  Future<void> _bootstrapPresenceOnly({
    required String subject,
    required DateTime startedAt,
  }) async {
    if (!running) return;
    final selfId = supabase.auth.currentUser?.id;
    if (selfId == null) return;
    try {
      await _presence.join(selfId: selfId, subject: subject, startedAt: startedAt);
      if (!running) { await _presence.leave(); return; }
      await _presenceSub?.cancel();
      _presenceSub = _presence.members.listen((list) {
        others = list.where((m) => m.userId != selfId).toList();
        notifyListeners();
      });
    } catch (e) {
      debugPrint('SessionController(web): Presence 실패(세션은 계속) → $e');
    }
    if (running) notifyListeners();
  }

  void pauseResume() {
    final s = state;
    if (s == null) return;
    final now = DateTime.now();
    state = s.paused ? AttentionScoring.resume(s, now) : AttentionScoring.pause(s, now);
    notifyListeners();
  }

  Future<SessionSummary> stop() async {
    _timer?.cancel();
    _timer = null;
    // 비동기 부트스트랩이 돌아가는 동안에도 즉시 false로 두어 카메라/Presence 경합을 줄입니다.
    running = false;
    notifyListeners();

    final s = state;
    if (s == null) throw StateError('Not started');

    final endedAt = DateTime.now();
    final subject = selectedSubjectLabel.trim().isEmpty
        ? null
        : selectedSubjectLabel.trim();
    final summary = AttentionScoring.finalize(
      s,
      endedAt,
      subject: subject,
      planItemId: selectedPlanItemId,
    );

    await _sub?.cancel();
    _sub = null;
    await _sensor.stop();

    await _presenceSub?.cancel();
    _presenceSub = null;
    await _presence.leave();

    return summary;
  }

  Future<SessionRewardResult> uploadAndApply(SessionSummary summary) async {
    final sessionId = await _sessionRepo.uploadSummary(summary);
    if (summary.planItemId != null) {
      await _sessionRepo.applyFocusedToPlanItem(
        planItemId: summary.planItemId!,
        focusedSeconds: summary.focusedSeconds,
      );
    }
    final blocksFromFocus = await _sessionRepo.awardCoinsForSession(
      sessionId: sessionId,
      focusedSeconds: summary.focusedSeconds,
    );
    await _sessionRepo.applySessionProgress(
      sessionId: sessionId,
      focusedSeconds: summary.focusedSeconds,
    );
    await _sessionRepo.applySquadSessionContribution(
      sessionId: sessionId,
      focusedSeconds: summary.focusedSeconds,
    );
    // Award daily plan bonus if eligible (>= 80% completion)
    final planBonus = await _sessionRepo.awardPlanBonusForToday();
    // Award streak bonus (+50) if yesterday+today both achieved plan bonus
    final streakBonus = await _sessionRepo.awardStreakBonusForToday();

    return SessionRewardResult(
      blocksFromFocus: blocksFromFocus,
      planBonus: planBonus,
      streakBonus: streakBonus,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _presenceSub?.cancel();
    _sensor.stop();
    _presence.dispose();
    super.dispose();
  }
}

