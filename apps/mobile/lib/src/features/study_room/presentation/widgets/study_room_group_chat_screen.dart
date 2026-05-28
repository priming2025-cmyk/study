import 'package:flutter/material.dart';

import '../../domain/study_room_models.dart';
import '../../infra/study_room_controller.dart';

/// 셋터디 방 단체 채팅 — DM과 동일하게 전체 화면으로 열립니다.
class StudyRoomGroupChatScreen extends StatefulWidget {
  final StudyRoomController controller;
  const StudyRoomGroupChatScreen({super.key, required this.controller});

  @override
  State<StudyRoomGroupChatScreen> createState() => _StudyRoomGroupChatScreenState();
}

class _StudyRoomGroupChatScreenState extends State<StudyRoomGroupChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    await widget.controller.sendMessage(text);
    if (!mounted) return;
    _textCtrl.clear();
    _scrollToBottom();
  }

  String _labelFor(String userId) {
    final name = widget.controller.displayNameFor(userId)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return userId.length > 8 ? userId.substring(0, 8) : userId;
  }

  @override
  Widget build(BuildContext context) {
    final selfId = widget.controller.selfId ?? '';
    final messages = widget.controller.roomChatMessages;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('단체 채팅'),
            Text(
              '셋터디 방 전체 · ${widget.controller.members.length + 1}명',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      '방에 있는 친구들과 대화를 시작해 보세요',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      return _MessageBubble(
                        message: msg,
                        isMine: msg.userId == selfId,
                        senderLabel: _labelFor(msg.userId),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 8,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 8,
                top: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: '단체 메시지 입력…',
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
                    color: Theme.of(context).colorScheme.primary,
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

class _MessageBubble extends StatelessWidget {
  final StudyRoomMessage message;
  final bool isMine;
  final String senderLabel;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.senderLabel,
  });

  String _formatTime(DateTime at) {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                senderLabel,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMine) ...[
                Text(
                  _formatTime(message.createdAt),
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMine ? cs.primary : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft:
                          isMine ? const Radius.circular(14) : Radius.zero,
                      bottomRight:
                          isMine ? Radius.zero : const Radius.circular(14),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: tt.bodyMedium?.copyWith(
                      color: isMine ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                ),
              ),
              if (!isMine) ...[
                const SizedBox(width: 6),
                Text(
                  _formatTime(message.createdAt),
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
