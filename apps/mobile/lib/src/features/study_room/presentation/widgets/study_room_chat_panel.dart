import 'package:flutter/material.dart';
import '../../domain/study_room_models.dart';

/// 채팅: 최신 메시지가 아래에 보이고, 짧은 높이만 노출 후 위로 스크롤.
class StudyRoomChatPanel extends StatefulWidget {
  final List<StudyRoomMessage> messages;
  final String selfId;
  final Future<void> Function(String content) onSendMessage;
  final bool isFocusMode;

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

    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text('채팅', style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: n,
                      itemBuilder: (context, index) {
                        final msg = widget.messages[n - 1 - index];
                        final isMine = msg.userId == widget.selfId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment:
                                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      decoration: const InputDecoration(
                        hintText: '응원 메시지를 남겨보세요',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                      onSubmitted: (_) => _handleSend(),
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: _handleSend,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
