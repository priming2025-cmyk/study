import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// 안드로이드/ios 기본 공유 시트 스타일:
/// - 상단: 텍스트 미리보기 + 복사
/// - 하단: OS 네이티브 공유 시트 열기
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
        // 미리보기 카드 (스크린샷 상단 카드) — 탭/복사 아이콘으로 전체 텍스트 복사
        Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _text.isEmpty ? null : () => _copyMessage(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Icon(
                      Icons.subject_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          previewLine1,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          previewLine2,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '복사',
                    onPressed: _text.isEmpty ? null : () => _copyMessage(context),
                    icon: Icon(Icons.copy_rounded, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // OS 기본 공유 시트 (카톡/메시지/인스타 등은 OS가 알아서 라우팅)
        Builder(
          builder: (btnContext) => OutlinedButton.icon(
            onPressed: _text.isEmpty ? null : () => _nativeShare(btnContext),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('공유'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
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
