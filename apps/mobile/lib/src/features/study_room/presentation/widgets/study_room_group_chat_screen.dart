import 'package:flutter/material.dart';

import '../../infra/study_room_controller.dart';
import 'study_room_chat_panel.dart';

/// 셋터디 방 단체 채팅(방 전체 공개) — DM처럼 “새 화면”으로 열리는 형태.
class StudyRoomGroupChatScreen extends StatefulWidget {
  final StudyRoomController controller;
  const StudyRoomGroupChatScreen({super.key, required this.controller});

  @override
  State<StudyRoomGroupChatScreen> createState() => _StudyRoomGroupChatScreenState();
}

class _StudyRoomGroupChatScreenState extends State<StudyRoomGroupChatScreen> {
  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selfId = widget.controller.selfId ?? '';
    final msgs = widget.controller.roomChatMessages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('단체 채팅'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: StudyRoomChatPanel(
          messages: msgs,
          selfId: selfId,
          onSendMessage: widget.controller.sendMessage,
          isFocusMode: false,
          displayNameForUser: (uid) =>
              widget.controller.displayNameFor(uid)?.trim().isNotEmpty == true
                  ? widget.controller.displayNameFor(uid)!.trim()
                  : (uid.length > 8 ? uid.substring(0, 8) : uid),
        ),
      ),
    );
  }
}

