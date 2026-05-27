import 'package:flutter/material.dart';

/// 앱 전역에서 사용할 Navigator key.
///
/// 푸시 알림(FCM 등) 탭에서 현재 화면과 무관하게 채팅 화면으로 이동할 때 사용합니다.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

