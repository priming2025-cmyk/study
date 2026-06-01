import 'package:flutter/material.dart';

import '../../domain/study_room_models.dart';
import '../../infra/study_room_controller.dart';
import 'study_room_chat_message_menu.dart';

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
  StudyRoomMessage? _replyingTo;

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

  String _labelFor(String userId) {
    final name = widget.controller.displayNameFor(userId)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return userId.length > 8 ? userId.substring(0, 8) : userId;
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    var body = text;
    final reply = _replyingTo;
    if (reply != null) {
      final quote = reply.content.trim();
      if (quote.isNotEmpty) {
        final excerpt =
            quote.length > 60 ? '${quote.substring(0, 60)}…' : quote;
        body = '↩ ${_labelFor(reply.userId)}: $excerpt\n$text';
      }
    }

    await widget.controller.sendMessage(body);
    if (!mounted) return;
    _textCtrl.clear();
    setState(() => _replyingTo = null);
    _scrollToBottom();
  }

  Future<void> _onMessageLongPress(StudyRoomMessage msg) async {
    final action = await showStudyRoomMessageActionSheet(
      context,
      message: msg,
      senderLabel: _labelFor(msg.userId),
    );
    if (action == null || !mounted) return;
    await handleStudyRoomMessageAction(
      context: context,
      action: action,
      message: msg,
      senderLabel: _labelFor(msg.userId),
      onReply: (m) => setState(() => _replyingTo = m),
      onNotice: widget.controller.setGroupNotice,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selfId = widget.controller.selfId ?? '';
    final messages = widget.controller.roomChatMessages;
    final notice = widget.controller.groupNotice;

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
          if (notice != null)
            StudyRoomGroupNoticeBanner(
              notice: notice,
              senderLabel: _labelFor(notice.userId),
              onClear: widget.controller.clearGroupNotice,
            ),
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
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: () => _onMessageLongPress(msg),
                        child: _MessageBubble(
                          message: msg,
                          isMine: msg.userId == selfId,
                          senderLabel: _labelFor(msg.userId),
                        ),
                      );
                    },
                  ),
          ),
          if (_replyingTo != null)
            _ReplyPreviewBar(
              label: _labelFor(_replyingTo!.userId),
              text: _replyingTo!.content,
              onCancel: () => setState(() => _replyingTo = null),
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

class _ReplyPreviewBar extends StatelessWidget {
  final String label;
  final String text;
  final VoidCallback onCancel;

  const _ReplyPreviewBar({
    required this.label,
    required this.text,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final excerpt = text.trim();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '답장 · $label: ${excerpt.length > 28 ? '${excerpt.substring(0, 28)}…' : excerpt}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onPrimaryContainer,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: '답장 취소',
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
