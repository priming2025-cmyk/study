import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 삼성·안드로이드 「텍스트 공유」 스타일: 미리보기 카드 + 링크 복사 + 앱 아이콘 행.
class ShareMessageChannels extends StatelessWidget {
  /// 공유 시트에 넣을 전체 텍스트
  final String message;

  /// 카드 첫 줄 (예: 우리 같이 공부하자!)
  final String previewLine1;

  /// 카드 둘째 줄 (예: 입장코드: ABC123)
  final String previewLine2;

  /// 입장·초대 링크 (별도 복사)
  final String? shareLink;

  final String copyMessageSuccessText;
  final String copyLinkSuccessText;

  const ShareMessageChannels({
    super.key,
    required this.message,
    required this.previewLine1,
    required this.previewLine2,
    this.shareLink,
    this.copyMessageSuccessText = '초대 메시지가 복사됐어요',
    this.copyLinkSuccessText = '입장 링크가 복사됐어요',
  });

  String get _text => message.trim();
  String get _link => shareLink?.trim() ?? '';

  Future<void> _copyMessage(BuildContext context) async {
    if (_text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(copyMessageSuccessText)),
    );
  }

  Future<void> _copyLink(BuildContext context) async {
    if (_link.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(copyLinkSuccessText)),
    );
  }

  Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _nativeShare(BuildContext context) async {
    if (_text.isEmpty) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _text,
          subject: '셋터디 초대',
          sharePositionOrigin: _shareOrigin(context),
        ),
      );
    } catch (_) {
      if (context.mounted) await _copyMessage(context);
    }
  }

  Future<void> _launchSms(BuildContext context) async {
    if (_text.isEmpty) return;
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(_text)}');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) await _nativeShare(context);
    } catch (_) {
      if (context.mounted) await _nativeShare(context);
    }
  }

  Future<void> _launchGmail(BuildContext context) async {
    if (_text.isEmpty) return;
    final uri = Uri.parse(
      'mailto:?subject=${Uri.encodeComponent('셋터디 초대')}'
      '&body=${Uri.encodeComponent(_text)}',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) await _nativeShare(context);
    } catch (_) {
      if (context.mounted) await _nativeShare(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 미리보기 카드 (텍스트 공유 상단 카드)
        Material(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _text.isEmpty ? null : () => _copyMessage(context),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes_rounded,
                    color: cs.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          previewLine1,
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (previewLine2.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            previewLine2,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '메시지 복사',
                    onPressed: _text.isEmpty ? null : () => _copyMessage(context),
                    icon: Icon(Icons.copy_rounded, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_link.isNotEmpty) ...[
          const SizedBox(height: 12),
          Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, size: 20, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      _link,
                      style: tt.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '링크 복사',
                    onPressed: () => _copyLink(context),
                    icon: Icon(Icons.copy_rounded, size: 20, color: cs.primary),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // 앱 아이콘 행 (카카오톡 · 메시지 · Gmail · 밴드 · 인스타)
        Builder(
          builder: (shareContext) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareAppTarget(
                label: '카카오톡',
                color: const Color(0xFFFEE500),
                iconColor: const Color(0xFF191919),
                icon: Icons.chat_bubble_rounded,
                onTap: _text.isEmpty ? null : () => _nativeShare(shareContext),
              ),
              _ShareAppTarget(
                label: '메시지',
                color: const Color(0xFF34C759),
                iconColor: Colors.white,
                icon: Icons.sms_rounded,
                onTap: _text.isEmpty ? null : () => _launchSms(shareContext),
              ),
              _ShareAppTarget(
                label: 'Gmail',
                color: Colors.white,
                iconColor: const Color(0xFFEA4335),
                icon: Icons.mail_outline_rounded,
                border: Border.all(color: cs.outlineVariant),
                onTap: _text.isEmpty ? null : () => _launchGmail(shareContext),
              ),
              _ShareAppTarget(
                label: '밴드',
                color: const Color(0xFF21C531),
                iconColor: Colors.white,
                icon: Icons.groups_rounded,
                onTap: _text.isEmpty ? null : () => _nativeShare(shareContext),
              ),
              _ShareAppTarget(
                label: '인스타',
                color: const Color(0xFFE1306C),
                iconColor: Colors.white,
                icon: Icons.camera_alt_rounded,
                onTap: _text.isEmpty ? null : () => _nativeShare(shareContext),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 시스템 공유 시트 (첨부 사진과 동일 — 카톡·연락처 등)
        Builder(
          builder: (btnContext) => OutlinedButton.icon(
            onPressed: _text.isEmpty ? null : () => _nativeShare(btnContext),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('더 많은 앱으로 공유'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareAppTarget extends StatelessWidget {
  final String label;
  final Color color;
  final Color iconColor;
  final IconData icon;
  final VoidCallback? onTap;
  final BoxBorder? border;

  const _ShareAppTarget({
    required this.label,
    required this.color,
    required this.iconColor,
    required this.icon,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: border,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
