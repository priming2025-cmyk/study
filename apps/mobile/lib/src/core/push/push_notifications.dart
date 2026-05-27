import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routing/root_navigator_key.dart';
import '../study/study_activity_gate.dart';
import '../../features/social/presentation/friend_dm_chat_screen.dart';
import '../supabase/supabase_client.dart';

final FlutterLocalNotificationsPlugin _localPlugin = FlutterLocalNotificationsPlugin();
const _prefKeyIsStudying = 'setudy_is_studying';
bool _localInited = false;

Future<void> _ensureLocalInited() async {
  if (_localInited) return;
  _localInited = true;
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _localPlugin.initialize(initSettings);
}

Future<void> _showFriendDmLocalNotification({
  required String title,
  required String body,
  required String payloadJson,
}) async {
  await _ensureLocalInited();
  const android = AndroidNotificationDetails(
    'friend_dm_fcm',
    '친구 메시지',
    channelDescription: '공부 중에는 알림이 표시되지 않아요.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  const ios = DarwinNotificationDetails();
  await _localPlugin.show(
    payloadJson.hashCode & 0x7fffffff,
    title,
    body,
    const NotificationDetails(android: android, iOS: ios),
    payload: payloadJson,
  );
}

/// 앱 백그라운드/종료 상태에서 수신되는 경우 호출됩니다.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init is required in background isolate.
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  final isStudying = prefs.getBool(_prefKeyIsStudying) ?? StudyActivityGate.isStudying;
  if (isStudying) return;

  final data = message.data;
  if (data['type'] != 'friend_dm') return;

  final peerId = data['peer_id'];
  final peerDisplayName = data['peer_display_name'] ?? '';
  final senderName = data['sender_name'] ?? '친구';
  final body = data['body'] ?? '';

  if (peerId == null || peerId.isEmpty) return;

  final payloadJson = jsonEncode({
    'peerId': peerId,
    'peerDisplayName': peerDisplayName,
  });

  await _showFriendDmLocalNotification(
    title: senderName,
    body: body,
    payloadJson: payloadJson,
  );
}

/// 푸시(FCM 등) 연동은 여기서 초기화·권한을 모읍니다.
///
/// 방해 최소화 전략:
/// 1) foreground에서는 알림을 "표시하지 않습니다". 대신 이미 Realtime로 화면에 메시지가 갱신되기 때문입니다.
/// 2) background/종료 상태에서만 로컬 알림을 표시하되, SharedPreferences의 `setudy_is_studying` 값을 기준으로 공부 중이면 알림을 버립니다.
abstract final class PushNotifications {
  static Future<void> initAfterLaunch() async {
    await Firebase.initializeApp();

    // background handler 등록(최초 1회)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initLocalPluginWithTapHandler();

    final messaging = FirebaseMessaging.instance;

    // iOS 권한
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 토큰 등록
    await _registerFcmToken(messaging);
    messaging.onTokenRefresh.listen((t) => _registerFcmToken(messaging, tokenOverride: t));

    // foreground 수신: UI(Realtime)로 이미 보이므로 무시
    FirebaseMessaging.onMessage.listen((_) {});

    // 앱이 백그라운드/종료 상태에서 탭된 경우
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _handleRemoteMessageTap(initial);
    }
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleRemoteMessageTap(m));
  }

  static Future<void> _initLocalPluginWithTapHandler() async {
    if (_localInited) return;
    _localInited = true;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final obj = jsonDecode(payload) as Map<String, dynamic>;
          final peerId = obj['peerId'] as String?;
          final peerDisplayName = obj['peerDisplayName'] as String? ?? '';
          if (peerId == null || peerId.isEmpty) return;

          rootNavigatorKey.currentState?.push(
            MaterialPageRoute<void>(
              builder: (_) => FriendDmChatScreen(
                peerId: peerId,
                peerDisplayName: peerDisplayName,
              ),
            ),
          );
        } catch (_) {}
      },
    );
  }

  static Future<void> _registerFcmToken(FirebaseMessaging messaging,
      {String? tokenOverride}) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    final token = tokenOverride ?? await messaging.getToken();
    if (token == null || token.isEmpty) return;

    try {
      await supabase.from('fcm_tokens').upsert({
        'user_id': uid,
        'token': token,
        'device_platform': defaultTargetPlatform.toString(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // 토큰 저장은 실패해도 앱의 핵심 기능에는 영향이 없습니다.
    }
  }

  static void _handleRemoteMessageTap(RemoteMessage message) {
    final data = message.data;
    if (data['type'] != 'friend_dm') return;

    final peerId = data['peer_id'] as String?;
    final peerDisplayName = data['peer_display_name'] as String? ?? '';
    if (peerId == null || peerId.isEmpty) return;

    rootNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => FriendDmChatScreen(
          peerId: peerId,
          peerDisplayName: peerDisplayName,
        ),
      ),
    );
  }
}
