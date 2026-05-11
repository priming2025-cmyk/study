import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/study_up_oauth.dart';

/// NOL/트리플 스타일: 흰 배경 · 얇은 테두리 · 좌측 로고 · 가운데 정렬 문구 (애플 제외).
class ReferenceSocialAuthStrip extends StatelessWidget {
  const ReferenceSocialAuthStrip({
    super.key,
    required this.enabled,
    required this.onProviderTap,
    this.spacing = 12,
  });

  final bool enabled;
  final Future<void> Function(OAuthProvider provider) onProviderTap;
  final double spacing;

  static const _h = 52.0;

  @override
  Widget build(BuildContext context) {
    final outline = BorderSide(color: Theme.of(context).colorScheme.outlineVariant);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OutlinedSocialTile(
          onTap: enabled ? () => onProviderTap(OAuthProvider.kakao) : null,
          outlineColor: outline.color,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE500),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.chat_bubble, size: 18, color: Color(0xFF191919)),
          ),
          label: '카카오로 시작하기',
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: onSurface),
        ),
        SizedBox(height: spacing),
        _OutlinedSocialTile(
          onTap: enabled ? () => onProviderTap(StudyUpOAuth.naver) : null,
          outlineColor: outline.color,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF03C75A),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Text(
              'N',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          label: '네이버로 시작하기',
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: onSurface),
        ),
        SizedBox(height: spacing),
        _OutlinedSocialTile(
          onTap: enabled ? () => onProviderTap(OAuthProvider.google) : null,
          outlineColor: outline.color,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            alignment: Alignment.center,
            child: Text(
              'G',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade600,
              ),
            ),
          ),
          label: '구글로 시작하기',
          labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: onSurface),
        ),
      ],
    );
  }
}

class _OutlinedSocialTile extends StatelessWidget {
  const _OutlinedSocialTile({
    required this.onTap,
    required this.outlineColor,
    required this.leading,
    required this.label,
    required this.labelStyle,
  });

  final VoidCallback? onTap;
  final Color outlineColor;
  final Widget leading;
  final String label;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(10);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: shape,
      child: InkWell(
        onTap: onTap,
        borderRadius: shape,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: outlineColor),
          ),
          child: SizedBox(
            height: ReferenceSocialAuthStrip._h,
            child: Row(
              children: [
                const SizedBox(width: 14),
                leading,
                Expanded(
                  child: Text(label, textAlign: TextAlign.center, style: labelStyle),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
