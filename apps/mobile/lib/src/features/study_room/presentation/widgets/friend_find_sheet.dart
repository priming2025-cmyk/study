import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/sheet_header_bar.dart';
import '../../../social/data/friend_dm_providers.dart';
import '../../../motivation/domain/motivation_models.dart';
import 'friend_incoming_requests_section.dart';

/// 이름·이메일로 친구를 검색해 요청을 보내는 시트.
class FriendFindSheet extends ConsumerStatefulWidget {
  const FriendFindSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const FriendFindSheet(),
    );
  }

  @override
  ConsumerState<FriendFindSheet> createState() => _FriendFindSheetState();
}

class _FriendFindSheetState extends ConsumerState<FriendFindSheet> {
  final _queryCtrl = TextEditingController();
  List<FriendSearchResult> _results = const [];
  final Set<String> _sentUserIds = {};
  bool _searching = false;
  String? _error;
  int _incomingKey = 0;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _error = '2글자 이상 입력해 주세요';
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    final repo = ref.read(motivationRepositoryProvider);
    final list = await repo.findUsersForFriend(q);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = list;
      if (list.isEmpty) _error = '검색 결과가 없어요';
    });
  }

  Future<void> _sendRequest(FriendSearchResult user) async {
    final repo = ref.read(motivationRepositoryProvider);
    final result = await repo.sendFriendRequestSafe(toUserId: user.userId);
    if (!mounted) return;

    if (result.offerAccept && result.incomingRequestId != null) {
      await repo.acceptFriendRequest(result.incomingRequestId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.displayName}님과 친구가 됐어요')),
      );
      setState(() => _incomingKey++);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );

    if (result.success) {
      setState(() => _sentUserIds.add(user.userId));
      ref.invalidate(friendDmThreadsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeaderBar(title: '친구 찾기'),
            FriendIncomingRequestsSection(
              key: ValueKey('find_incoming_$_incomingKey'),
              onChanged: () => setState(() => _incomingKey++),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: '이름 · 이메일 · 아이디',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _searching ? null : _search,
                    child: _searching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('검색'),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  _error!,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _results.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (context, i) {
                  final u = _results[i];
                  final alreadySent = _sentUserIds.contains(u.userId);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.secondaryContainer,
                      child: Text(
                        u.displayName.isNotEmpty
                            ? u.displayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      u.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      u.userId.length > 8
                          ? u.userId.substring(0, 8)
                          : u.userId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: alreadySent
                        ? Text(
                            '요청 보냄',
                            style: tt.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : FilledButton.tonal(
                            onPressed: () => _sendRequest(u),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(64, 36),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text('추가'),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
