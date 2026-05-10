import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/push/push_notifications.dart';
import 'src/core/supabase/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In MVP we load .env from assets. Do not commit real secrets.
  await dotenv.load(fileName: '.env');
  SupabaseConfig.validateForRun();

  await PushNotifications.initAfterLaunch();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      // 웹: URL에 세션이 있으면 복구 (PKCE 리다이렉트 대응)
      detectSessionInUri: true,
    ),
  );

  runApp(const ProviderScope(child: StudyUpApp()));
}

