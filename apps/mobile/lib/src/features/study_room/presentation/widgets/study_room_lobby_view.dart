import 'package:flutter/material.dart';

class StudyRoomLobbyView extends StatelessWidget {
  final TextEditingController roomNameCtrl;
  final TextEditingController roomIdCtrl;
  final bool joining;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const StudyRoomLobbyView({
    super.key,
    required this.roomNameCtrl,
    required this.roomIdCtrl,
    required this.joining,
    required this.onCreate,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 안내 카드
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.group_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('같이 공부하기', style: Theme.of(context).textTheme.titleMedium),
                ]),
                const SizedBox(height: 8),
                Text(
                  '최대 4명이 방에 입장해 서로 공부 중인지 확인할 수 있어요.\n'
                  '1분마다 스냅샷이 자동으로 공유됩니다. 영상은 전송되지 않습니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

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
