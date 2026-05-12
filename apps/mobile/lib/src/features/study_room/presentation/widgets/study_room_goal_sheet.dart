import 'package:flutter/material.dart';

/// 방 입장 전 오늘의 목표 한 줄을 입력받습니다. 취소 시 `null`.
///
/// [TextEditingController]는 시트 State가 소유해, 모달이 완전히 내려간 뒤
/// dispose 되도록 합니다. (시트 밖에서 즉시 dispose 하면 `_dependents.isEmpty`
/// assertion이 날 수 있음)
Future<String?> showStudyRoomGoalSheet(BuildContext context) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _StudyRoomGoalSheetBody(),
  );
}

class _StudyRoomGoalSheetBody extends StatefulWidget {
  const _StudyRoomGoalSheetBody();

  @override
  State<_StudyRoomGoalSheetBody> createState() => _StudyRoomGoalSheetBodyState();
}

class _StudyRoomGoalSheetBodyState extends State<_StudyRoomGoalSheetBody> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('오늘의 목표', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '스터디방 친구들에게 보여줄 한 줄 목표를 적어 주세요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '예: 수학 단원정리 2개',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _submit,
                child: const Text('입장하기'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
