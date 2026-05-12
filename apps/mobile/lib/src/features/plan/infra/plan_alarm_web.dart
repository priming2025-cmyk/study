// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

bool _inited = false;

class _Pending {
  final String id;
  final DateTime when;
  final String subject;
  bool fired = false;
  _Pending({required this.id, required this.when, required this.subject});
}

final List<_Pending> _pending = [];

Future<void> planAlarmInit() async {
  if (_inited) return;
  _inited = true;
  Timer.periodic(const Duration(seconds: 15), (_) {
    final now = DateTime.now();
    for (final p in _pending) {
      if (p.fired) continue;
      if (p.when.isAfter(now)) continue;
      p.fired = true;
      if (html.Notification.supported &&
          html.Notification.permission == 'granted') {
        html.Notification(
          'Study-up · ${p.subject}',
          body: '계획한 시작 시간이에요.',
        );
      }
    }
  });
}

Future<void> planAlarmSchedule({
  required String planItemId,
  required String subject,
  required DateTime whenLocal,
}) async {
  await planAlarmInit();
  if (html.Notification.supported &&
      html.Notification.permission != 'granted') {
    await html.Notification.requestPermission();
  }
  _pending.removeWhere((e) => e.id == planItemId);
  _pending.add(
    _Pending(id: planItemId, when: whenLocal, subject: subject),
  );
}

Future<void> planAlarmCancel(String planItemId) async {
  _pending.removeWhere((e) => e.id == planItemId);
}
