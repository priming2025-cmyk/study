import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../motivation/domain/motivation_models.dart';

/// 받은 친구 요청 목록 + 수락 버튼.
class FriendIncomingRequestsSection extends ConsumerWidget {
  final VoidCallback? onChanged;

  const FriendIncomingRequestsSection({super.key, this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<IncomingFriendRequest>>(
      future: ref.read(motivationRepositoryProvider).listIncomingFriendRequests(),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();

        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded,
                      size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    '받은 친구 요청',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${list.length}',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...list.map((r) => _RequestTile(
                  request: r,
                  onAccept: () async {
                    final repo = ref.read(motivationRepositoryProvider);
                    await repo.acceptFriendRequest(r.id);
                    onChanged?.call();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${r.fromDisplayName}님과 친구가 됐어요'),
                        ),
                      );
                    }
                  },
                )),
            const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  final IncomingFriendRequest request;
  final VoidCallback onAccept;

  const _RequestTile({
    required this.request,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Text(
          request.fromDisplayName.isNotEmpty
              ? request.fromDisplayName[0].toUpperCase()
              : '?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: cs.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(
        request.fromDisplayName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '친구 요청',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: FilledButton(
        onPressed: onAccept,
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: const Text('수락'),
      ),
    );
  }
}
