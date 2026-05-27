import 'package:flutter_local_notifications/flutter_local_notifications.dart';

bool _inited = false;
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

Future<void> dmNotificationInit() async {
  if (_inited) return;
  _inited = true;
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _plugin.initialize(initSettings);
}

Future<void> dmNotificationShow({
  required String title,
  required String body,
  required String payload,
}) async {
  await dmNotificationInit();
  const android = AndroidNotificationDetails(
    'friend_dm',
    '친구 메시지',
    channelDescription: '친구 DM 알림 (공부 중에는 표시하지 않음)',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  const ios = DarwinNotificationDetails();
  await _plugin.show(
    payload.hashCode & 0x7fffffff,
    title,
    body,
    const NotificationDetails(android: android, iOS: ios),
    payload: payload,
  );
}
