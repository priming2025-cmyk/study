import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';

/// 기록 화면 — 표시 이름 편집.
class ProfileNameEditor extends ConsumerStatefulWidget {
  final String? initialName;
  final VoidCallback? onSaved;

  const ProfileNameEditor({
    super.key,
    this.initialName,
    this.onSaved,
  });

  @override
  ConsumerState<ProfileNameEditor> createState() => _ProfileNameEditorState();
}

class _ProfileNameEditorState extends ConsumerState<ProfileNameEditor> {
  late final TextEditingController _ctrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void didUpdateWidget(covariant ProfileNameEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.initialName != widget.initialName) {
      _ctrl.text = widget.initialName ?? '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final err = await ref
        .read(motivationRepositoryProvider)
        .updateDisplayName(_ctrl.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
    });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
      return;
    }
    widget.onSaved?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이름을 저장했어요')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = widget.initialName?.trim();

    if (_editing) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              maxLength: 20,
              decoration: InputDecoration(
                hintText: '이름',
                isDense: true,
                counterText: '',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            tooltip: '저장',
          ),
          IconButton(
            onPressed: _saving
                ? null
                : () => setState(() {
                      _editing = false;
                      _ctrl.text = widget.initialName ?? '';
                    }),
            icon: const Icon(Icons.close_rounded),
            tooltip: '취소',
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            name != null && name.isNotEmpty ? name : '이름을 설정해 주세요',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: '수정',
          onPressed: () => setState(() => _editing = true),
          icon: Icon(Icons.edit_outlined, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
