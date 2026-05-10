import 'dart:convert';

import 'plan_models.dart';

/// 오늘 계획을 로컬 SQLite 한 행에 넣기 위한 JSON 직렬화.
abstract final class TodayPlanCodec {
  static String toJsonString(TodayPlan plan) {
    return jsonEncode(_toJson(plan));
  }

  static TodayPlan fromJsonString(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return _fromJson(map);
  }

  static Map<String, dynamic> _toJson(TodayPlan plan) {
    return {
      'id': plan.id,
      'date': plan.date.toIso8601String(),
      'title': plan.title,
      'items': plan.items.map(_itemToJson).toList(),
    };
  }

  static Map<String, dynamic> _itemToJson(PlanItem e) {
    return {
      'id': e.id,
      'subject': e.subject,
      'targetSeconds': e.targetSeconds,
      'actualSeconds': e.actualSeconds,
      'isDone': e.isDone,
    };
  }

  static TodayPlan _fromJson(Map<String, dynamic> map) {
    final itemsRaw = map['items'] as List<dynamic>? ?? const [];
    final items = itemsRaw
        .map((e) => _itemFromJson(e as Map<String, dynamic>))
        .toList();
    return TodayPlan(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      title: map['title'] as String?,
      items: items,
    );
  }

  static PlanItem _itemFromJson(Map<String, dynamic> e) {
    return PlanItem(
      id: e['id'] as String,
      subject: e['subject'] as String,
      targetSeconds: (e['targetSeconds'] as num).toInt(),
      actualSeconds: ((e['actualSeconds'] ?? 0) as num).toInt(),
      isDone: (e['isDone'] ?? false) as bool,
    );
  }
}
