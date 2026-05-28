import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:setudy/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routing/app_deep_link_listener.dart';
import 'core/routing/root_navigator_key.dart';
import 'core/routing/go_router_refresh_stream.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_provider.dart';
import 'core/theme/theme_lab_screen.dart';
import 'features/auth/auth_feature_flags.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/sign_up_screen.dart';
import 'features/coins/presentation/coin_history_screen.dart';
import 'features/coins/presentation/coin_earning_guide_screen.dart';
import 'features/family/presentation/family_hub_screen.dart';
import 'features/legal/legal_routes.dart';
import 'features/motivation/presentation/gacha_shop_screen.dart';
import 'features/motivation/presentation/social_hub_screen.dart';
import 'features/plan/presentation/plan_editor_screen.dart';
import 'features/session/presentation/session_screen.dart';
import 'features/stats/presentation/stats_screen.dart';
import 'features/study_room/domain/study_room_join_code.dart';
import 'features/study_room/infra/pending_study_room_join.dart';
import 'features/study_room/presentation/study_room_screen.dart';
import 'shell/app_shell.dart';

/// Supabase Site URL 등으로 들어오는 잘못된 경로를 정규화합니다.
String? _normalizeUnknownEntryPath(String path, {required bool authed}) {
  final trimmed = path.trim();
  final lower = trimmed.toLowerCase().replaceAll(' ', '');
  if (trimmed == '/' ||
      lower == '/home' ||
      trimmed == '/Home' ||
      lower == 'home') {
    return authed ? '/session' : '/login';
  }
  return null;
}

final _routerProvider = Provider<GoRouter>((ref) {
  final authStream = Supabase.instance.client.auth.onAuthStateChange;
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/session',
    refreshListenable: GoRouterRefreshStream(authStream),
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final authed = session != null;
      final loc = state.uri.path;

      final normalized = _normalizeUnknownEntryPath(loc, authed: authed);
      if (normalized != null) return normalized;

      final onLogin = loc == '/login';
      final onSignUp = loc == '/signup';
      final onAuthScreen = onLogin || onSignUp;
      final themeLab = kDebugMode && loc == '/dev/theme';
      final legal = loc.startsWith('/legal/');

      if (onSignUp) return '/login';

      const skipLoginGate =
          kDebugMode && AuthFeatureFlags.devBypassAuthGate;
      if (!authed && !skipLoginGate && !onAuthScreen && !themeLab && !legal) {
        final rawJoin = state.uri.queryParameters['join'] ??
            state.uri.queryParameters['code'];
        if (rawJoin != null && rawJoin.trim().isNotEmpty) {
          final code = normalizeJoinCode(rawJoin);
          if (code.isNotEmpty) {
            PendingStudyRoomJoin.save(code);
          }
        } else if (loc == '/room/join') {
          final code = state.uri.queryParameters['code'];
          if (code != null && code.trim().isNotEmpty) {
            PendingStudyRoomJoin.save(normalizeJoinCode(code));
          }
        }
        return '/login';
      }
      if (authed && onAuthScreen) return '/session';
      return null;
    },
    errorBuilder: (context, state) {
      final authed = Supabase.instance.client.auth.currentSession != null;
      final target = authed ? '/session' : '/login';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(target);
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final authed = Supabase.instance.client.auth.currentSession != null;
          return authed ? '/session' : '/login';
        },
      ),
      GoRoute(
        path: '/Home',
        redirect: (_, __) {
          final authed = Supabase.instance.client.auth.currentSession != null;
          return authed ? '/session' : '/login';
        },
      ),
      GoRoute(
        path: '/room/join',
        redirect: (context, state) {
          final code = state.uri.queryParameters['code']?.trim() ?? '';
          if (code.isEmpty) return '/room';
          return '/room?join=${Uri.encodeComponent(code)}';
        },
      ),
      GoRoute(
        path: '/friend',
        redirect: (context, state) {
          final ref = state.uri.queryParameters['ref']?.trim() ??
              state.uri.queryParameters['user']?.trim() ??
              '';
          if (ref.isEmpty) return '/room';
          return '/room?friendRef=${Uri.encodeComponent(ref)}';
        },
      ),
      GoRoute(
        path: '/home',
        redirect: (_, __) {
          final authed = Supabase.instance.client.auth.currentSession != null;
          return authed ? '/session' : '/login';
        },
      ),
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
        parentNavigatorKey: rootNavigatorKey,
        path: '/coins',
        builder: (context, state) => const CoinHistoryScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/coins/how',
        builder: (context, state) => const CoinEarningGuideScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/family',
        builder: (context, state) => const FamilyHubScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/gacha',
        builder: (context, state) => const GachaShopScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/social',
        builder: (context, state) => const SocialHubScreen(),
      ),
      ...buildLegalRoutes(rootNavigatorKey),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            preload: true,
            routes: [
              GoRoute(
                path: '/session',
                builder: (context, state) => const SessionScreen(),
              ),
              GoRoute(
                path: '/session/quick',
                builder: (context, state) =>
                    const SessionScreen(autoStart: true),
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
                path: '/room',
                builder: (context, state) => const StudyRoomScreen(),
              ),
              GoRoute(
                path: '/room/quick',
                builder: (context, state) =>
                    const StudyRoomScreen(quickJoin: true),
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

class SetudyApp extends ConsumerWidget {
  const SetudyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    bindAppDeepLinks(router);
    final themeId = ref.watch(appThemeIdProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      theme: AppTheme.light(themeId),
      darkTheme: AppTheme.dark(themeId),
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
