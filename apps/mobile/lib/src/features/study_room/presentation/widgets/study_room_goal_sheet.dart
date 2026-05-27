import 'package:flutter/material.dart';

import '../../../../core/widgets/sheet_header_bar.dart';

/// 방 입장 전 스터디 그룹 목표 한 줄을 입력받습니다. 취소 시 `null`.
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
          const SheetHeaderBar(title: '스터디 그룹의 목표'),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '2시간 함께공부',
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
