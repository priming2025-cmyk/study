import 'package:flutter/material.dart';
import '../../domain/study_room_models.dart';

/// 채팅: 최신 메시지가 아래에 보이고, [visibleMessageLines]줄 높이만 노출 후 그 안에서 스크롤.
class StudyRoomChatPanel extends StatefulWidget {
  final List<StudyRoomMessage> messages;
  final String selfId;
  final Future<void> Function(String content) onSendMessage;
  final bool isFocusMode;

  /// 말풍선 리스트 영역 높이(텍스트 약 [lines]줄 분량 + 여백).
  static double messageListHeightForLines(BuildContext context, {int lines = 3}) {
    final mq = MediaQuery.of(context);
    final t = Theme.of(context).textTheme.bodyMedium!;
    final fs = t.fontSize ?? 14;
    final h = t.height ?? 1.25;
    final line = mq.textScaler.scale(fs) * h;
    return line * lines + 28;
  }

  /// 헤더 + 메시지 리스트 + 한 줄 입력 + 하단 세이프 영역 합산.
  static double totalOuterHeight(BuildContext context, {int visibleMessageLines = 3}) {
    final mq = MediaQuery.of(context);
    const header = 22.0;
    const inputRow = 46.0;
    return header +
        messageListHeightForLines(context, lines: visibleMessageLines) +
        inputRow +
        mq.padding.bottom;
  }

  const StudyRoomChatPanel({
    super.key,
    required this.messages,
    required this.selfId,
    required this.onSendMessage,
    required this.isFocusMode,
  });

  @override
  State<StudyRoomChatPanel> createState() => _StudyRoomChatPanelState();
}

class _StudyRoomChatPanelState extends State<StudyRoomChatPanel> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(covariant StudyRoomChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    await widget.onSendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFocusMode) {
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_moon_outlined,
                    size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(
                  '집중 보조 켜짐',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '다른 앱 전환·알림은 OS 집중 모드·스크린타임으로 줄여 보세요. 채팅은 아래에서 다시 켤 수 있어요.',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final n = widget.messages.length;
    final listH = StudyRoomChatPanel.messageListHeightForLines(context, lines: 3);

    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text('채팅', style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          SizedBox(
            height: listH,
            width: double.infinity,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: n == 0
                  ? Center(
                      child: Text(
                        '첫 메시지를 남겨 보세요',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      itemCount: n,
                      itemBuilder: (context, index) {
                        final msg = widget.messages[n - 1 - index];
                        final isMine = msg.userId == widget.selfId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment:
                                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(12),
                                    topRight: const Radius.circular(12),
                                    bottomLeft: isMine ? const Radius.circular(12) : Radius.zero,
                                    bottomRight: isMine ? Radius.zero : const Radius.circular(12),
                                  ),
                                ),
                                child: Text(msg.content),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textCtrl,
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          hintText: '메시지',
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        ),
                        onSubmitted: (_) => _handleSend(),
                        minLines: 1,
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      icon: const Icon(Icons.send_rounded, size: 22),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: _handleSend,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
