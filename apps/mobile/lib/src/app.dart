import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:study_up/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routing/go_router_refresh_stream.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_lab_screen.dart';
import 'features/auth/auth_feature_flags.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/sign_up_screen.dart';
import 'features/coins/presentation/coin_history_screen.dart';
import 'features/coins/presentation/coin_earning_guide_screen.dart';
import 'features/family/presentation/family_hub_screen.dart';
import 'features/legal/legal_routes.dart';
import 'features/home/presentation/dashboard_screen.dart';
import 'features/motivation/presentation/gacha_shop_screen.dart';
import 'features/motivation/presentation/social_hub_screen.dart';
import 'features/plan/presentation/plan_editor_screen.dart';
import 'features/session/presentation/session_screen.dart';
import 'features/stats/presentation/stats_screen.dart';
import 'features/study_room/presentation/study_room_screen.dart';
import 'shell/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final _routerProvider = Provider<GoRouter>((ref) {
  final authStream = Supabase.instance.client.auth.onAuthStateChange;
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: GoRouterRefreshStream(authStream),
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final onLogin = state.matchedLocation == '/login';
      final onSignUp = state.matchedLocation == '/signup';
      final onAuthScreen = onLogin || onSignUp;
      final authed = session != null;
      final themeLab = kDebugMode && state.matchedLocation == '/dev/theme';
      final legal = state.matchedLocation.startsWith('/legal/');

      // /signup 경로는 /login 으로 통합됨 (로그인 화면 내 탭 전환)
      if (onSignUp) return '/login';

      const skipLoginGate =
          kDebugMode && AuthFeatureFlags.devBypassAuthGate;
      if (!authed &&
          !skipLoginGate &&
          !onAuthScreen &&
          !themeLab &&
          !legal) {
        return '/login';
      }
      if (authed && onAuthScreen) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/dev/theme',
          builder: (context, state) => const ThemeLabScreen(),
        ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/coins',
        builder: (context, state) => const CoinHistoryScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/coins/how',
        builder: (context, state) => const CoinEarningGuideScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/family',
        builder: (context, state) => const FamilyHubScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/gacha',
        builder: (context, state) => const GachaShopScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/social',
        builder: (context, state) => const SocialHubScreen(),
      ),
      ...buildLegalRoutes(_rootNavigatorKey),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                builder: (context, state) => const PlanEditorScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/session',
                builder: (context, state) => const SessionScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/room',
                builder: (context, state) => const StudyRoomScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class StudyUpApp extends ConsumerWidget {
  const StudyUpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      localeListResolutionCallback: (deviceLocales, supported) {
        const fallback = Locale('ko');
        if (deviceLocales == null || deviceLocales.isEmpty) {
          return fallback;
        }
        for (final device in deviceLocales) {
          for (final app in supported) {
            if (app.languageCode == device.languageCode) {
              return app;
            }
          }
        }
        return fallback;
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}

