import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    return text.contains('provider is not enabled') ||
        text.contains('Unsupported provider') ||
        text.contains('validation_failed');
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
      final ok = await supabase.auth.signInWithOAuth(
        provider,
        redirectTo: AuthRedirectConfig.oauthRedirectUri(),
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
