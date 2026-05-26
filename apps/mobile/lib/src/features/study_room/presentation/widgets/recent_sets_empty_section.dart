import 'package:flutter/material.dart';

/// 최근 셋이 없을 때 — 셋 만들기 / 입장 (헤더 + 버튼과 동일).
class RecentSetsEmptySection extends StatelessWidget {
  final bool joining;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoin;

  const RecentSetsEmptySection({
    super.key,
    required this.joining,
    required this.onCreateRoom,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '최근 셋',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.groups_2_outlined,
                  size: 40,
                  color: cs.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  '아직 참여한 셋이 없어요',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: joining ? null : onCreateRoom,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('셋 만들기'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: joining ? null : onJoin,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('입장'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
