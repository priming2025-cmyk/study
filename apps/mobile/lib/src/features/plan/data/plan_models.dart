class PlanItemDraft {
  final String subject;
  final int targetSeconds;
  final int priority;

  const PlanItemDraft({
    required this.subject,
    required this.targetSeconds,
    required this.priority,
  });
}

class PlanDraft {
  final DateTime date;
  final String? title;
  final List<PlanItemDraft> items;

  const PlanDraft({
    required this.date,
    this.title,
    required this.items,
  });
}

class PlanItem {
  final String id;
  final String subject;
  final int targetSeconds;
  final int actualSeconds;
  final bool isDone;
  /// 사용자가 정한 시작 시각(서버 timestamptz, UTC 저장 → 앱에서 toLocal 표시)
  final DateTime? scheduledStartAt;
  final bool reminderEnabled;

  const PlanItem({
    required this.id,
    required this.subject,
    required this.targetSeconds,
    required this.actualSeconds,
    required this.isDone,
    this.scheduledStartAt,
    this.reminderEnabled = false,
  });

  double get completionRate {
    if (targetSeconds <= 0) return 0;
    final r = actualSeconds / targetSeconds;
    if (r < 0) return 0;
    if (r > 1) return 1;
    return r;
  }

  PlanItem copyWith({
    String? id,
    String? subject,
    int? targetSeconds,
    int? actualSeconds,
    bool? isDone,
    DateTime? scheduledStartAt,
    bool? reminderEnabled,
  }) {
    return PlanItem(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      actualSeconds: actualSeconds ?? this.actualSeconds,
      isDone: isDone ?? this.isDone,
      scheduledStartAt: scheduledStartAt ?? this.scheduledStartAt,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    );
  }
}

class TodayPlan {
  final String id;
  final DateTime date;
  final String? title;
  final List<PlanItem> items;

  const TodayPlan({
    required this.id,
    required this.date,
    required this.title,
    required this.items,
  });

  int get totalTargetSeconds => items.fold(0, (acc, e) => acc + e.targetSeconds);
  int get totalActualSeconds => items.fold(0, (acc, e) => acc + e.actualSeconds);

  double get completionRate {
    final t = totalTargetSeconds;
    if (t <= 0) return 0;
    final r = totalActualSeconds / t;
    if (r < 0) return 0;
    if (r > 1) return 1;
    return r;
  }
}
