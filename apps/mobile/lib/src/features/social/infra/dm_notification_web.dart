// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<void> dmNotificationInit() async {}

Future<void> dmNotificationShow({
  required String title,
  required String body,
  required String payload,
}) async {
  if (!html.Notification.supported) return;
  if (html.Notification.permission != 'granted') {
    await html.Notification.requestPermission();
  }
  if (html.Notification.permission == 'granted') {
    html.Notification('Setudy · $title', body: body);
  }
}
