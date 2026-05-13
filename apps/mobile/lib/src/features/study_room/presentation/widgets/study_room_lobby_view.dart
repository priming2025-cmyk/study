import 'package:flutter/material.dart';

class StudyRoomLobbyView extends StatelessWidget {
  final TextEditingController roomNameCtrl;
  final TextEditingController roomIdCtrl;
  final bool joining;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final String? recentRoomId;
  final VoidCallback? onQuickJoinRecent;

  const StudyRoomLobbyView({
    super.key,
    required this.roomNameCtrl,
    required this.roomIdCtrl,
    required this.joining,
    required this.onCreate,
    required this.onJoin,
    this.recentRoomId,
    this.onQuickJoinRecent,
  });

  @override
  Widget build(BuildContext context) {
    String shortId(String id) =>
        id.length <= 8 ? id : '${id.substring(0, 8)}…';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (recentRoomId != null && onQuickJoinRecent != null) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('최근 방으로 빠른 입장'),
              subtitle: Text('방 ID: ${shortId(recentRoomId!)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: joining ? null : onQuickJoinRecent,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 방 만들기
        Text('새 방 만들기', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: roomNameCtrl,
          decoration: const InputDecoration(
            labelText: '방 이름',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: joining ? null : onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text(joining ? '처리 중…' : '방 만들기'),
          ),
        ),
        const SizedBox(height: 32),

        // 방 ID로 참여
        Text('ID로 참여하기', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: roomIdCtrl,
          decoration: const InputDecoration(
            labelText: '방 ID 붙여넣기',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: joining ? null : onJoin,
            icon: const Icon(Icons.login_rounded),
            label: const Text('참여하기'),
          ),
        ),
      ],
    );
  }
}
