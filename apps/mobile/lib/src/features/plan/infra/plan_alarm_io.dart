import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _inited = false;
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

int _notificationId(String planItemId) => planItemId.hashCode & 0x7fffffff;

Future<void> planAlarmInit() async {
  if (_inited) return;
  _inited = true;
  tzdata.initializeTimeZones();
  final tzName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(tzName));

  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _plugin.initialize(initSettings);

  final android = _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.requestNotificationsPermission();
}

Future<void> planAlarmSchedule({
  required String planItemId,
  required String subject,
  required DateTime whenLocal,
}) async {
  await planAlarmInit();
  if (whenLocal.isBefore(DateTime.now().subtract(const Duration(seconds: 3)))) {
    return;
  }
  final when = tz.TZDateTime.from(whenLocal, tz.local);
  const android = AndroidNotificationDetails(
    'plan_study_start',
    '계획 시작 알림',
    channelDescription: '계획한 과목 시작 시각 알림',
    importance: Importance.high,
    priority: Priority.high,
  );
  const ios = DarwinNotificationDetails();
  await _plugin.zonedSchedule(
    _notificationId(planItemId),
    '공부 시작',
    subject,
    when,
    const NotificationDetails(android: android, iOS: ios),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

Future<void> planAlarmCancel(String planItemId) async {
  await _plugin.cancel(_notificationId(planItemId));
}
