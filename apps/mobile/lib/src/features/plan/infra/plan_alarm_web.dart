// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

bool _inited = false;

class _Pending {
  final String id;
  final DateTime when;
  final String subject;
  final bool fiveMinBefore;
  bool fired = false;
  _Pending({
    required this.id,
    required this.when,
    required this.subject,
    required this.fiveMinBefore,
  });
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
        if (p.fiveMinBefore) {
          html.Notification(
            'Setudy · 셋터디 5분 전입니다',
            body: '${p.subject} · 5분 후 시작',
          );
        } else {
          html.Notification(
            'Setudy · ${p.subject}',
            body: '계획한 시작 시간이에요.',
          );
        }
      }
    }
  });
}

Future<void> planAlarmSchedule({
  required String planItemId,
  required String subject,
  required DateTime whenLocal,
  bool fiveMinBefore = false,
}) async {
  await planAlarmInit();
  if (html.Notification.supported &&
      html.Notification.permission != 'granted') {
    await html.Notification.requestPermission();
  }
  final key = '${planItemId}_${fiveMinBefore ? '5m' : 'start'}';
  _pending.removeWhere((e) => e.id == key);
  _pending.add(
    _Pending(
      id: key,
      when: whenLocal,
      subject: subject,
      fiveMinBefore: fiveMinBefore,
    ),
  );
}

Future<void> planAlarmCancel(String planItemId) async {
  _pending.removeWhere((e) => e.id.startsWith('${planItemId}_'));
}
