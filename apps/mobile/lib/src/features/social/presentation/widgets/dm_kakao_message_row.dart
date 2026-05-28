import 'package:flutter/material.dart';

/// 카카오톡형 DM 말풍선 (프로필 + 이름 + 말풍선).
class DmKakaoMessageRow extends StatelessWidget {
  final bool isMine;
  final String peerName;
  final String? peerAvatarUrl;
  final String text;
  final String time;
  final String? imageUrl;
  final String? replyPreview;

  const DmKakaoMessageRow({
    super.key,
    required this.isMine,
    required this.peerName,
    this.peerAvatarUrl,
    required this.text,
    required this.time,
    this.imageUrl,
    this.replyPreview,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (isMine) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(time, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 10)),
            const SizedBox(width: 6),
            Flexible(child: _bubble(context, cs, tt, alignEnd: true)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: cs.secondaryContainer,
            backgroundImage:
                peerAvatarUrl != null && peerAvatarUrl!.isNotEmpty
                    ? NetworkImage(peerAvatarUrl!)
                    : null,
            child: (peerAvatarUrl == null || peerAvatarUrl!.isEmpty)
                ? Text(
                    peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onSecondaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peerName,
                  style: tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                _bubble(context, cs, tt, alignEnd: false),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt, {
    required bool alignEnd,
  }) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMine ? cs.primary : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (replyPreview != null && replyPreview!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '답장: $replyPreview',
                style: tt.labelSmall?.copyWith(
                  color: isMine ? cs.onPrimary.withValues(alpha: 0.85) : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (imageUrl != null && imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : const SizedBox(
                      width: 180,
                      height: 120,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
              ),
            ),
            if (text.isNotEmpty) const SizedBox(height: 6),
          ],
          if (text.isNotEmpty)
            Text(
              text,
              style: tt.bodyMedium?.copyWith(
                color: isMine ? cs.onPrimary : cs.onSurface,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}
