import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../plan/data/plan_models.dart';
import '../../plan/data/plan_repository.dart';
import '../data/session_repository.dart';
import '../domain/attention_scoring.dart';
import '../domain/attention_signals.dart';
import '../domain/session_summary.dart';
import '../infra/face_attention_sensor.dart';
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
  final newSubjectController = TextEditingController();
  int quickMinutes = 50;

  List<PresenceMember> others = const [];

  CameraDescription? frontCamera;
  bool appInForeground = true;

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

  Future<void> init() async {
    await _initCamera();
    await _loadTodayPlan();
  }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final front =
          cams.where((c) => c.lensDirection == CameraLensDirection.front).toList();
      frontCamera = front.isNotEmpty ? front.first : (cams.isNotEmpty ? cams.first : null);
    } catch (_) {}
  }

  Future<void> _loadTodayPlan() async {
    try {
      final cached = await _planRepo.loadCachedTodayPlan();
      if (cached != null) {
        todayPlan = cached;
        if (cached.items.isNotEmpty) {
          selectedPlanItemId = cached.items.first.id;
          selectedSubjectLabel = cached.items.first.subject;
        }
        notifyListeners();
      }
      todayPlan = await _planRepo.fetchTodayPlan();
      if (todayPlan != null && todayPlan!.items.isNotEmpty) {
        final first = todayPlan!.items.first;
        selectedPlanItemId = first.id;
        selectedSubjectLabel = first.subject;
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

  Future<void> addPlannedSubjectAndSelect() async {
    final subject = newSubjectController.text.trim();
    if (subject.isEmpty) return;
    final planId = await _planRepo.createOrUpdateTodayPlan();
    final item = await _planRepo.addItem(
      planId: planId,
      subject: subject,
      targetSeconds: quickMinutes * 60,
    );
    todayPlan = await _planRepo.fetchTodayPlan();
    selectPlanItem(item);
    newSubjectController.clear();
    notifyListeners();
  }

  Future<void> start() async {
    if (running || starting) return;
    starting = true;
    notifyListeners();

    final subject = selectedSubjectLabel.trim().isEmpty
        ? newSubjectController.text.trim()
        : selectedSubjectLabel.trim();
    if (subject.isEmpty) {
      starting = false;
      notifyListeners();
      throw StateError('과목이 필요합니다.');
    }

    final now = DateTime.now();
    state = AttentionScoringState.started(now);
    running = true;
    starting = false;
    notifyListeners();

    final cam = frontCamera;
    if (cam != null || kIsWeb) {
      await _sensor.start(
        camera: cam,
        appInForeground: () => appInForeground,
      );
      await _sub?.cancel();
      _sub = _sensor.stream.listen((s) {
        signals = s;
        notifyListeners();
      });
    } else {
      signals = AttentionSignals(
        facePresent: false,
        multiFace: false,
        appInForeground: appInForeground,
      );
      notifyListeners();
    }

    // presence: show others studying now
    final selfId = supabase.auth.currentUser?.id;
    if (selfId != null) {
      await _presence.join(selfId: selfId, subject: subject, startedAt: now);
      await _presenceSub?.cancel();
      _presenceSub = _presence.members.listen((list) {
        // show everyone except me
        others = list.where((m) => m.userId != selfId).toList();
        notifyListeners();
      });
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state;
      if (s == null) return;
      state = AttentionScoring.tick(
        state: s,
        now: DateTime.now(),
        signals: signals,
      );
      notifyListeners();
    });
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

    running = false;
    notifyListeners();

    await _sub?.cancel();
    _sub = null;
    await _sensor.stop();

    await _presenceSub?.cancel();
    _presenceSub = null;
    await _presence.leave();

    return summary;
  }

  Future<void> uploadAndApply(SessionSummary summary) async {
    final sessionId = await _sessionRepo.uploadSummary(summary);
    if (summary.planItemId != null) {
      await _sessionRepo.applyFocusedToPlanItem(
        planItemId: summary.planItemId!,
        focusedSeconds: summary.focusedSeconds,
      );
    }
    await _sessionRepo.awardCoinsForSession(
      sessionId: sessionId,
      focusedSeconds: summary.focusedSeconds,
    );
    // Award daily plan bonus if eligible (>= 80% completion)
    await _sessionRepo.awardPlanBonusForToday();
    // Award streak bonus (+50) if yesterday+today both achieved plan bonus
    await _sessionRepo.awardStreakBonusForToday();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _presenceSub?.cancel();
    _sensor.stop();
    _presence.dispose();
    newSubjectController.dispose();
    super.dispose();
  }
}

