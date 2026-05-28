import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 초대 메시지 복사 + 메시지/카톡·인스타(공유시트)/Gmail 등으로 보내기.
class ShareMessageChannels extends StatelessWidget {
  final String message;
  final String copySuccessText;

  const ShareMessageChannels({
    super.key,
    required this.message,
    this.copySuccessText = '초대 메시지가 복사됐어요',
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(copySuccessText)),
    );
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        await _copy(context);
      }
    } catch (_) {
      if (context.mounted) await _copy(context);
    }
  }

  Future<void> _shareSystem(BuildContext context) async {
    try {
      await SharePlus.instance.share(ShareParams(text: message, subject: '셋터디 초대'));
    } catch (_) {
      if (context.mounted) await _copy(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final text = message.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  text,
                  style: tt.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
              IconButton(
                tooltip: '복사',
                onPressed: text.isEmpty ? null : () => _copy(context),
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '보내기',
          style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ChannelChip(
              icon: Icons.sms_outlined,
              label: '메시지',
              onTap: text.isEmpty
                  ? null
                  : () => _launch(
                        context,
                        Uri.parse('sms:?body=${Uri.encodeComponent(text)}'),
                      ),
            ),
            _ChannelChip(
              icon: Icons.chat_bubble_outline,
              label: '카카오톡',
              onTap: text.isEmpty ? null : () => _shareSystem(context),
            ),
            _ChannelChip(
              icon: Icons.camera_alt_outlined,
              label: '인스타',
              onTap: text.isEmpty ? null : () => _shareSystem(context),
            ),
            _ChannelChip(
              icon: Icons.mail_outline_rounded,
              label: 'Gmail',
              onTap: text.isEmpty
                  ? null
                  : () => _launch(
                        context,
                        Uri.parse(
                          'mailto:?subject=${Uri.encodeComponent('셋터디 초대')}'
                          '&body=${Uri.encodeComponent(text)}',
                        ),
                      ),
            ),
            _ChannelChip(
              icon: Icons.ios_share_rounded,
              label: '더보기',
              onTap: text.isEmpty ? null : () => _shareSystem(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ChannelChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 18, color: cs.primary),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
    );
  }
}
