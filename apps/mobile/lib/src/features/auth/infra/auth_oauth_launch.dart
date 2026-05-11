import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/auth_redirect_config.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/ui/app_snacks.dart';

/// 카카오·네이버·구글 등 OAuth 브라우저/외부 앱 실행.
abstract final class AuthOAuthLaunch {
  static String _providerLabel(OAuthProvider provider) {
    return switch (provider.name) {
      'kakao' => '카카오',
      'google' => 'Google',
      'naver' => '네이버',
      _ => provider.name,
    };
  }

  /// GoTrue `validation_failed` / `provider is not enabled` 등 서버 문구를 사용자 안내로 바꿉니다.
  static bool _isProviderDisabled(Object error) {
    final text = switch (error) {
      AuthException e => '${e.message} ${e.code ?? ''}',
      final Object o => o.toString(),
    };
    if (text.contains('provider is not enabled') ||
        text.contains('Unsupported provider') ||
        text.contains('validation_failed')) {
      return true;
    }
    // 일부 환경에서는 응답 본문 전체가 JSON 문자열로 전달됩니다.
    return text.contains('"error_code":"validation_failed"');
  }

  static void _showError(BuildContext context, OAuthProvider provider, Object e) {
    final label = _providerLabel(provider);
    if (_isProviderDisabled(e)) {
      AppSnacks.show(
        context,
        '$label 로그인이 Supabase 프로젝트에서 꺼져 있거나 등록되지 않았습니다.\n'
        'Supabase 대시보드 → Authentication → Providers 에서 '
        '$label(네이버는 Custom OIDC일 수 있음)를 켜고 Client ID/Secret을 저장한 뒤 다시 시도해 주세요.',
      );
      return;
    }
    final msg = switch (e) {
      AuthException e => e.message,
      final Object o => o.toString(),
    };
    AppSnacks.show(context, msg);
  }

  static Future<void> signInWithProvider(
    BuildContext context,
    OAuthProvider provider,
  ) async {
    try {
      final redirectTo = AuthRedirectConfig.oauthRedirectUri();
      if (kIsWeb) {
        // 기본 `signInWithOAuth` 는 웹에서 `_self` 로 이동해, provider 비활성 시
        // 현재 탭 전체가 JSON 오류 페이지로 바뀝니다. 새 탭으로 열어 앱 탭을 유지합니다.
        final res = await supabase.auth.getOAuthSignInUrl(
          provider: provider,
          redirectTo: redirectTo,
        );
        final uri = Uri.parse(res.url);
        final ok = await launchUrl(
          uri,
          webOnlyWindowName: '_blank',
        );
        if (!context.mounted) return;
        if (!ok) {
          AppSnacks.show(
            context,
            '로그인 창을 열 수 없습니다. 팝업이 차단됐는지 확인해 주세요.',
          );
        }
        return;
      }
      final ok = await supabase.auth.signInWithOAuth(
        provider,
        redirectTo: redirectTo,
      );
      if (!context.mounted) return;
      if (!ok) {
        AppSnacks.show(
          context,
          '로그인 창을 열 수 없습니다. 팝업·리디렉트가 막혀 있지 않은지 확인해 주세요.',
        );
      }
    } on AuthException catch (e) {
      if (!context.mounted) return;
      _showError(context, provider, e);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, provider, e);
    }
  }
}
