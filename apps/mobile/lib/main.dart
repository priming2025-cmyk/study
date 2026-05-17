import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/push/push_notifications.dart';
import 'src/core/supabase/supabase_config.dart';
import 'src/features/auth/auth_feature_flags.dart';
import 'src/features/plan/infra/plan_alarm_service.dart';
import 'src/features/session/infra/web_platform_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In MVP we load .env from assets. Do not commit real secrets.
  await dotenv.load(fileName: '.env');
  SupabaseConfig.validateForRun();

  await PushNotifications.initAfterLaunch();
  await PlanAlarmService.init();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      // 웹: URL에 세션이 있으면 복구 (PKCE 리다이렉트 대응)
      detectSessionInUri: true,
    ),
  );

  // 디버그 모드 + 인증 우회 플래그가 켜져 있고 로그인된 사용자가 없으면
  // Supabase 익명 로그인을 자동 실행합니다.
  // → DB 쓰기 작업(과목 추가·세션 저장 등)에 실제 user_id 가 생겨 정상 동작합니다.
  // 전제 조건: Supabase 대시보드 Authentication → Providers → Anonymous 활성화 필요.
  if (kDebugMode && AuthFeatureFlags.devBypassAuthGate) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      try {
        await Supabase.instance.client.auth.signInAnonymously();
      } catch (e) {
        // 익명 로그인 실패 시 앱은 계속 실행하되 콘솔에 안내를 출력합니다.
        debugPrint(
          '[DevBypass] 익명 로그인 실패: $e\n'
          '→ Supabase 대시보드 > Authentication > Providers > Anonymous 를 활성화하세요.',
        );
      }
    }
  }

  if (kIsWeb) {
    unawaited(warmUpWebAttentionStack());
  }

  runApp(const ProviderScope(child: StudyUpApp()));
}

