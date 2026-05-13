import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/family_repository.dart';
import 'family_child_tile.dart';
import 'family_format.dart';
import 'widgets/supporter_student_convert_row.dart';

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
      if (_role == 'parent' || _role == 'teacher') {
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
      const SnackBar(
        content: Text('내 계정 ID를 복사했어요. 신뢰하는 서포터에게만 알려 주세요.'),
      ),
    );
  }

  Future<void> _link() async {
    final raw = _studentIdCtrl.text.trim();
    if (!looksLikeUuid(raw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학생 계정 ID(UUID) 형식인지 확인해 주세요.')),
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
        appBar: AppBar(title: const Text('서포터 연결')),
        body: Center(child: Text(_error!)),
      );
    }

    final isSupporter = _role == 'parent' || _role == 'teacher';

    return Scaffold(
      appBar: AppBar(
        title: const Text('서포터 연결'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            isSupporter
                ? '서포터로 연결된 학생의 집중 요약만 볼 수 있어요. 아래에서 모은 블럭을 교환 코인으로 바꿔 줄 수 있습니다. (영상·얼굴은 저장하지 않습니다.)'
                : '서포터에게 아래 ID를 알려 주면, 요약 확인과 블럭→교환 코인 전환을 받을 수 있어요.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          if (!isSupporter) ...[
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
          if (isSupporter) ...[
            TextField(
              controller: _studentIdCtrl,
              decoration: const InputDecoration(
                labelText: '학생 계정 ID',
                hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _link,
              child: const Text('학생과 연결하기'),
            ),
            const SizedBox(height: 20),
            Text('연결된 학생', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_children.isEmpty)
              Text(
                '아직 연결된 학생이 없어요. 위에 학생이 알려준 ID를 붙여 넣어 주세요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else ...[
              ..._children.map((c) => FamilyChildTile(student: c)),
              const SizedBox(height: 18),
              Text(
                '블럭 → 교환 코인',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '학생 지갑에 들어 있는 블럭을 줄여, 기프티콘 등에 쓸 수 있는 교환 코인으로 돌려줄 수 있어요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              ..._children.map((c) => SupporterStudentConvertRow(student: c)),
            ],
          ],
        ],
      ),
    );
  }
}
