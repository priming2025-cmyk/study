import 'package:flutter/material.dart';

import '../../../../core/widgets/sheet_header_bar.dart';
import '../../data/contacts_friend_service.dart';

/// 연락처에서 셋터디 친구 찾기 바텀시트.
class ContactsImportSheet extends StatefulWidget {
  const ContactsImportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ContactsImportSheet(),
    );
  }

  @override
  State<ContactsImportSheet> createState() => _ContactsImportSheetState();
}

class _ContactsImportSheetState extends State<ContactsImportSheet> {
  bool _loading = false;
  List<ContactFriendCandidate> _list = const [];
  String? _error;

  Future<void> _sync() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var local = await ContactsFriendService.loadDeviceContacts();
      if (local.isEmpty) {
        setState(() {
          _error = '연락처를 불러오지 못했거나 권한이 없어요.';
          _loading = false;
        });
        return;
      }
      local = await ContactsFriendService.matchSettudyUsers(local);
      await ContactsFriendService.markSynced();
      if (mounted) {
        setState(() {
          _list = local;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final onSettudy = _list.where((e) => e.onSettudy).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (_, scroll) => Material(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHeaderBar(
                    title: '연락처에서 친구 찾기',
                    subtitle:
                        '카카오톡·인스타처럼 연락처에 있는 사람 중 셋터디를 쓰는 친구를 찾아요. '
                        '번호는 친구 매칭에만 사용됩니다.',
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loading ? null : _sync,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.contacts_rounded),
                    label: Text(_loading ? '불러오는 중…' : '연락처 동기화'),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (onSettudy.isNotEmpty) ...[
                    Text('셋터디 사용 중',
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...onSettudy.map(
                      (c) => ListTile(
                        leading: CircleAvatar(child: Text(c.name[0])),
                        title: Text(c.name),
                        subtitle: Text(_maskPhone(c.phone)),
                        trailing: FilledButton.tonal(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${c.name}님에게 친구 요청 (준비 중)')),
                            );
                          },
                          child: const Text('추가'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_list.isNotEmpty) ...[
                    Text('전체 연락처',
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ..._list.take(80).map(
                      (c) => ListTile(
                        dense: true,
                        leading: Icon(
                          c.onSettudy ? Icons.verified : Icons.person_outline,
                          color: c.onSettudy ? cs.primary : cs.onSurfaceVariant,
                        ),
                        title: Text(c.name),
                        subtitle: Text(
                          c.onSettudy ? '셋터디 사용 중' : '초대하기',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _maskPhone(String p) {
    if (p.length < 4) return p;
    return '${p.substring(0, 3)}****${p.substring(p.length - 2)}';
  }
}
