import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/supabase/supabase_client.dart';

/// 친구 추가·앱 설치 유도용 웹 딥링크 (`/friend?ref=`).
String friendInviteLink({String? referrerUserId}) {
  final ref = (referrerUserId ?? supabase.auth.currentUser?.id ?? '').trim();
  final configured = dotenv.env['SETUDY_WEB_URL']?.trim();
  final base = (configured != null && configured.isNotEmpty)
      ? configured.replaceAll(RegExp(r'/$'), '')
      : (kIsWeb ? Uri.base.origin : '');
  if (base.isEmpty || ref.isEmpty) {
    return '/friend?ref=${Uri.encodeComponent(ref)}';
  }
  return '$base/friend?ref=${Uri.encodeComponent(ref)}';
}

String friendInviteMessage({String? referrerDisplayName}) {
  final link = friendInviteLink();
  final iosUrl = dotenv.env['SETUDY_APP_STORE_URL']?.trim();
  final androidUrl = dotenv.env['SETUDY_PLAY_STORE_URL']?.trim();

  final name = (referrerDisplayName ?? '').trim();
  final greet = name.isNotEmpty ? '$name님이 셋터디에서 같이 공부하자고 초대했어요!' : '셋터디에서 같이 공부해요!';

  final installLines = <String>[];
  if (iosUrl != null && iosUrl.isNotEmpty) installLines.add('iOS 설치: $iosUrl');
  if (androidUrl != null && androidUrl.isNotEmpty) {
    installLines.add('Android 설치: $androidUrl');
  }
  final installText =
      installLines.isEmpty ? '' : '\n\n${installLines.join('\n')}';

  return '$greet\n'
      '아래 링크를 누르면 앱이 열리거나 설치 후 바로 친구 추가할 수 있어요.\n'
      '$link$installText';
}
