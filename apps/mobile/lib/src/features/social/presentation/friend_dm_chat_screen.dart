import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/friend_dm_providers.dart';
import '../domain/friend_dm_models.dart';

/// 인스타 DM형 친구 1:1 채팅 전용 화면.
class FriendDmChatScreen extends ConsumerStatefulWidget {
  final String peerId;
  final String peerDisplayName;

  const FriendDmChatScreen({
    super.key,
    required this.peerId,
    required this.peerDisplayName,
  });

  @override
  ConsumerState<FriendDmChatScreen> createState() => _FriendDmChatScreenState();
}

class _FriendDmChatScreenState extends ConsumerState<FriendDmChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<FriendMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  FriendMessage? _replyingTo;

  static const _quickReplies = [
    '같이 공부하자! 📚',
    '지금 뭐해?',
    '화이팅! 💪',
    '셋터디 할래?',
  ];

  @override
  void initState() {
    super.initState();
    ref.read(friendDmActivePeerProvider.notifier).state = widget.peerId;
    _load();
    final repo = ref.read(friendDmRepositoryProvider);
    repo.addListener(_onRepo);
  }

  @override
  void dispose() {
    ref.read(friendDmRepositoryProvider).removeListener(_onRepo);
    ref.read(friendDmActivePeerProvider.notifier).state = null;
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onRepo() {
    _reloadFromRepo();
  }

  Future<void> _load() async {
    final repo = ref.read(friendDmRepositoryProvider);
    try {
      final list = await repo.fetchThread(widget.peerId);
      await repo.markRead(widget.peerId);
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('대화를 불러오지 못했어요: $e')),
      );
    }
  }

  void _reloadFromRepo() {
    ref.read(friendDmRepositoryProvider).fetchThread(widget.peerId).then((list) {
      if (!mounted) return;
      setState(() {
        if (list.isNotEmpty || _messages.isEmpty) {
          _messages = list;
        }
      });
      _scrollToBottom();
    }).catchError((_) {});
  }

  void _appendMessage(FriendMessage msg) {
    if (_messages.any((m) => m.id == msg.id)) return;
    setState(() => _messages = [..._messages, msg]);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _textCtrl.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    try {
      final sent = await ref.read(friendDmRepositoryProvider).sendMessage(
            peerId: widget.peerId,
            content: text,
            replyToMessageId: _replyingTo?.id,
          );
      if (preset == null) _textCtrl.clear();
      if (mounted) {
        setState(() {
          _replyingTo = null;
          _sending = false;
        });
      }
      _appendMessage(sent);
      await ref.read(friendDmRepositoryProvider).markRead(widget.peerId);
      ref.invalidate(friendDmThreadsProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전송에 실패했어요. 친구 관계·네트워크를 확인해 주세요.\n$e')),
        );
      }
    }
  }

  String _formatTime(DateTime at) {
    final local = at.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDay(DateTime at) {
    final local = at.toLocal();
    return '${local.month}월 ${local.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selfId = supabase.auth.currentUser?.id ?? '';
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.secondaryContainer,
              child: Text(
                widget.peerDisplayName.isNotEmpty
                    ? widget.peerDisplayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cs.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peerDisplayName,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '친구',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _EmptyChat(peerName: widget.peerDisplayName)
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final msg = _messages[i];
                          final isMine = msg.senderId == selfId;
                          FriendMessage? replyMsg;
                          if (msg.replyToMessageId != null) {
                            for (final r in _messages) {
                              if (r.id == msg.replyToMessageId) {
                                replyMsg = r;
                                break;
                              }
                            }
                          }
                          final replyPreview = replyMsg?.content.trim();
                          final replyPreviewText = (replyPreview == null ||
                                  replyPreview.isEmpty)
                              ? null
                              : replyPreview.length > 18
                                  ? '${replyPreview.substring(0, 18)}…'
                                  : replyPreview;
                          final showDay = i == 0 ||
                              !_sameDay(
                                _messages[i - 1].createdAt,
                                msg.createdAt,
                              );
                          return Column(
                            children: [
                              if (showDay)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    _formatDay(msg.createdAt),
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onLongPress: () {
                                  if (!mounted) return;
                                  setState(() => _replyingTo = msg);
                                },
                                child: _Bubble(
                                  text: msg.content,
                                  time: _formatTime(msg.createdAt),
                                  isMine: isMine,
                                  replyPreviewText: replyPreviewText,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
          if (!_loading)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  for (final q in _quickReplies)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(q, style: const TextStyle(fontSize: 12)),
                        onPressed: () => _send(q),
                        backgroundColor: cs.primaryContainer.withAlpha(120),
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                ],
              ),
            ),
          if (_replyingTo != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withAlpha(85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: cs.primary.withAlpha(120),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '답장: ${_replyingTo!.content.trim().length > 20 ? '${_replyingTo!.content.trim().substring(0, 20)}…' : _replyingTo!.content.trim()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _replyingTo = null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: '답장 취소',
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(color: cs.outlineVariant.withAlpha(80)),
                ),
              ),
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
                        hintText: '메시지 입력…',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(),
                    icon: _sending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}

class _EmptyChat extends StatelessWidget {
  final String peerName;

  const _EmptyChat({required this.peerName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: cs.primary.withAlpha(140),
            ),
            const SizedBox(height: 16),
            Text(
              '$peerName 님과 대화를 시작해 보세요',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '「같이 공부하자」 버튼으로\n셋터디 초대도 쉽게 보낼 수 있어요',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isMine;
  final String? replyPreviewText;

  const _Bubble({
    required this.text,
    required this.time,
    required this.isMine,
    this.replyPreviewText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        left: isMine ? 48 : 0,
        right: isMine ? 0 : 48,
      ),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (replyPreviewText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                constraints: const BoxConstraints(maxWidth: 240),
                decoration: BoxDecoration(
                  color: isMine
                      ? cs.primary.withAlpha(60)
                      : cs.onSurfaceVariant.withAlpha(35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '답장: $replyPreviewText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(
                    color: isMine ? cs.onPrimary : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isMine
                  ? LinearGradient(
                      colors: [cs.primary, cs.primary.withAlpha(220)],
                    )
                  : null,
              color: isMine ? null : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isMine ? 18 : 8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              style: tt.bodyMedium?.copyWith(
                color: isMine ? cs.onPrimary : cs.onSurface,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
