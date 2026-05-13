import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/family_repository.dart';

/// 서포터 화면에서 연결된 학생의 블럭 → 교환 코인 전환(MVP 1:1).
class SupporterStudentConvertRow extends ConsumerStatefulWidget {
  const SupporterStudentConvertRow({super.key, required this.student});

  final LinkedStudent student;

  @override
  ConsumerState<SupporterStudentConvertRow> createState() =>
      _SupporterStudentConvertRowState();
}

class _SupporterStudentConvertRowState
    extends ConsumerState<SupporterStudentConvertRow> {
  final _blocksCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _blocksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(int maxBlocks) async {
    final parsed = int.tryParse(_blocksCtrl.text.trim());
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전환할 블럭 수를 숫자로 입력해 주세요.')),
      );
      return;
    }
    if (parsed > maxBlocks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보유 블럭보다 많게 전환할 수 없어요.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(familyRepositoryProvider).supporterExchangeBlocksToRedeemCoins(
            studentId: widget.student.id,
            blocks: parsed,
          );
      _blocksCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$parsed 블럭을 교환 코인으로 전환했어요. (학생 지갑에 반영됨)'),
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('전환 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(familyRepositoryProvider);

    return FutureBuilder(
      future: repo.fetchWalletForUser(widget.student.id),
      builder: (context, snap) {
        final w = snap.data;
        final loading = snap.connectionState == ConnectionState.waiting && w == null;
        final blocks = w?.blocks ?? 0;
        final coins = w?.redeemCoins ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.student.displayName?.trim().isNotEmpty == true
                      ? widget.student.displayName!
                      : '학생',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  widget.student.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                if (loading)
                  const LinearProgressIndicator(minHeight: 3)
                else
                  Text(
                    '블럭 $blocks · 교환 코인 $coins',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _blocksCtrl,
                        decoration: const InputDecoration(
                          labelText: '전환 블럭 수',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed:
                          _busy || loading ? null : () => _submit(blocks),
                      child: Text(_busy ? '…' : '교환'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'MVP 규칙: 1블럭 → 1교환코인 (환율은 정책에 따라 변경될 수 있어요)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
