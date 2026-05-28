class FriendMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final String? replyToMessageId;
  final String? attachmentUrl;
  final String? attachmentType;
  final DateTime createdAt;

  const FriendMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    this.replyToMessageId,
    this.attachmentUrl,
    this.attachmentType,
    required this.createdAt,
  });

  factory FriendMessage.fromJson(Map<String, dynamic> j) => FriendMessage(
        id: j['id'] as String,
        senderId: j['sender_id'] as String,
        recipientId: j['recipient_id'] as String,
        content: j['content'] as String? ?? '',
        replyToMessageId: j['reply_to_message_id'] as String?,
        attachmentUrl: j['attachment_url'] as String?,
        attachmentType: j['attachment_type'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class FriendDmThread {
  final String peerId;
  final String peerDisplayName;
  final String? lastContent;
  final DateTime? lastAt;
  final int unreadCount;

  const FriendDmThread({
    required this.peerId,
    required this.peerDisplayName,
    this.lastContent,
    this.lastAt,
    this.unreadCount = 0,
  });

  factory FriendDmThread.fromJson(Map<String, dynamic> j) => FriendDmThread(
        peerId: j['peer_id'] as String,
        peerDisplayName: j['peer_display_name'] as String? ?? '친구',
        lastContent: j['last_content'] as String?,
        lastAt: j['last_at'] != null
            ? DateTime.parse(j['last_at'] as String)
            : null,
        unreadCount: ((j['unread_count'] ?? 0) as num).toInt(),
      );
}
