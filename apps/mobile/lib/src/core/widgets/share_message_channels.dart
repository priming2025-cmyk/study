import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// 삼성·안드로이드 「텍스트 공유」 스타일: 미리보기 카드 + 링크 복사 + 앱 아이콘 행.
class ShareMessageChannels extends StatelessWidget {
  /// 공유 시트에 넣을 전체 텍스트
  final String message;

  /// 카드 첫 줄 (예: 우리 같이 공부하자!)
  final String previewLine1;

  /// 카드 둘째 줄 (예: 입장코드: ABC123)
  final String previewLine2;

  final String copyMessageSuccessText;

  const ShareMessageChannels({
    super.key,
    required this.message,
    required this.previewLine1,
    required this.previewLine2,
    this.copyMessageSuccessText = '초대 메시지가 복사됐어요',
  });

  String get _text => message.trim();

  Future<void> _copyMessage(BuildContext context) async {
    if (_text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(copyMessageSuccessText)),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 미리보기 카드 (텍스트 공유 상단 카드) — 탭하면 전체 텍스트 복사
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
        const SizedBox(height: 14),

        // 시스템 공유 시트 (첨부 사진과 동일 — 카톡·연락처 등)
        Builder(
          builder: (btnContext) => OutlinedButton.icon(
            onPressed: _text.isEmpty ? null : () => _nativeShare(btnContext),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('공유하기'),
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
