import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/family_repository.dart';
import 'family_child_tile.dart';
import 'family_format.dart';

class FamilyHubScreen extends ConsumerStatefulWidget {
  const FamilyHubScreen({super.key});

  @override
  ConsumerState<FamilyHubScreen> createState() => _FamilyHubScreenState();
}

class _FamilyHubScreenState extends ConsumerState<FamilyHubScreen> {
  final _studentIdCtrl = TextEditingController();
  bool _loading = true;
  String? _role;
  List<LinkedStudent> _children = const [];
  String? _error;

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(familyRepositoryProvider);
      _role = await repo.fetchMyRole();
      if (_role == 'parent') {
        _children = await repo.fetchLinkedStudents();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyMyId() async {
    final id = supabase.auth.currentUser?.id;
    if (id == null) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('내 계정 ID를 복사했어요. 부모에게만 알려 주세요.')),
    );
  }

  Future<void> _link() async {
    final raw = _studentIdCtrl.text.trim();
    if (!looksLikeUuid(raw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자녀 계정 ID(UUID) 형식인지 확인해 주세요.')),
      );
      return;
    }
    try {
      await ref.read(familyRepositoryProvider).linkStudent(raw);
      _studentIdCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결했어요.')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('연결 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('가족 연결')),
        body: Center(child: Text(_error!)),
      );
    }

    final isParent = _role == 'parent';

    return Scaffold(
      appBar: AppBar(
        title: const Text('가족 연결'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            isParent
                ? '연결된 자녀의 집중 세션 요약만 볼 수 있어요. (영상·얼굴 데이터는 저장하지 않습니다.)'
                : '부모님께 아래 ID를 알려 주면, 부모님 앱에서 집중 기록 요약을 볼 수 있어요.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          if (!isParent) ...[
            Card(
              child: ListTile(
                title: const Text('내 계정 ID'),
                subtitle: Text(supabase.auth.currentUser?.id ?? '-'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: _copyMyId,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (isParent) ...[
            TextField(
              controller: _studentIdCtrl,
              decoration: const InputDecoration(
                labelText: '자녀 계정 ID',
                hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _link,
              child: const Text('자녀와 연결하기'),
            ),
            const SizedBox(height: 20),
            Text('연결된 자녀', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_children.isEmpty)
              Text(
                '아직 연결된 자녀가 없어요. 위에 자녀가 알려준 ID를 붙여 넣어 주세요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              ..._children.map((c) => FamilyChildTile(student: c)),
          ],
        ],
      ),
    );
  }
}
