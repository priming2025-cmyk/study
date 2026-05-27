import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';

import '../../features/study_room/domain/study_room_join_code.dart';

bool _bound = false;
StreamSubscription<Uri>? _sub;

/// iOS Universal Links / Android App Links → GoRouter 경로로 연결.
void bindAppDeepLinks(GoRouter router) {
  if (kIsWeb || _bound) return;
  _bound = true;

  final appLinks = AppLinks();

  _sub = appLinks.uriLinkStream.listen(
    (uri) => _routeDeepLink(router, uri),
    onError: (_) {},
  );

  unawaited(
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _routeDeepLink(router, uri);
    }),
  );
}

void _routeDeepLink(GoRouter router, Uri uri) {
  final path = uri.path;
  final rawJoin = uri.queryParameters['join'] ?? uri.queryParameters['code'];

  if (rawJoin != null && rawJoin.trim().isNotEmpty) {
    final code = normalizeJoinCode(rawJoin);
    if (code.isEmpty) return;
    router.go('/room?join=${Uri.encodeComponent(code)}');
    return;
  }

  if (path == '/room' || path.startsWith('/room/')) {
    router.go(uri.hasQuery ? '$path?${uri.query}' : path);
  }
}

/// 테스트/핫 리로드용 (일반 앱에서는 호출하지 않음).
Future<void> disposeAppDeepLinks() async {
  await _sub?.cancel();
  _sub = null;
  _bound = false;
}
