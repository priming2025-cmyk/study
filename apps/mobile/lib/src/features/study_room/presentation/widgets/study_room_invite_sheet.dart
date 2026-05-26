import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// 셋터디 참여 초대 시트.
/// "대기 중" 슬롯 탭 또는 별도 버튼에서 호출됩니다.
class StudyRoomInviteSheet extends StatelessWidget {
  final String roomId;

  const StudyRoomInviteSheet({super.key, required this.roomId});

  static Future<void> show(BuildContext context, {required String roomId}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => StudyRoomInviteSheet(roomId: roomId),
    );
  }

  String get _inviteText =>
      '우리 같이 공부하자!\n입장코드: $roomId\n\n셋터디(setudy) 앱을 열고 입력해 보세요!';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '친구 초대',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          // 메시지 미리보기 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '우리 같이 공부하자!',
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '입장코드: ',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Text(
                      roomId,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: roomId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('입장코드가 복사됐어요')),
                        );
                      },
                      child: Icon(Icons.copy_rounded, size: 16, color: cs.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 공유 버튼 (네이티브 공유 시트)
          FilledButton.icon(
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(text: _inviteText, subject: '셋터디 초대'),
              );
            },
            icon: const Icon(Icons.share_rounded),
            label: const Text('공유하기'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _inviteText));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('초대 메시지가 복사됐어요!')),
              );
            },
            icon: const Icon(Icons.content_copy_rounded),
            label: const Text('텍스트 복사'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
