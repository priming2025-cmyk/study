import 'package:flutter/material.dart';

import 'profile_avatar_editor.dart';
import 'profile_name_editor.dart';

/// 기록 > 나의 정보 — 요청한 2줄 레이아웃:
///
///   프로필           이름   ✎
/// (프로필자리)      메일주소
class ProfileCompactRow extends StatelessWidget {
  final String? avatarUrl;
  final String displayNameFallback;
  final String? displayName;
  final String? email;
  final VoidCallback? onSaved;

  const ProfileCompactRow({
    super.key,
    required this.avatarUrl,
    required this.displayNameFallback,
    required this.displayName,
    required this.email,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ProfileAvatarEditor(
          initialAvatarUrl: avatarUrl,
          displayNameFallback: displayNameFallback,
          onSaved: onSaved,
          showHint: false,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileNameEditor(
                initialName: displayName,
                onSaved: onSaved,
              ),
              if (email != null && email!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  email!.trim(),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

