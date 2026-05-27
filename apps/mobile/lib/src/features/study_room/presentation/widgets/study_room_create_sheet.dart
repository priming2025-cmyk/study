import 'package:flutter/material.dart';

import '../../../../core/widgets/sheet_header_bar.dart';
import '../../domain/study_room_default_name.dart';
import 'peer_count_selector_row.dart';

class StudyRoomCreateRequest {
  final String name;
  final int maxPeers;

  const StudyRoomCreateRequest({required this.name, required this.maxPeers});
}

/// 셋 만들기 시트. 취소 시 `null`.
Future<StudyRoomCreateRequest?> showStudyRoomCreateSheet(
  BuildContext context, {
  int initialMaxPeers = 4,
}) async {
  return showModalBottomSheet<StudyRoomCreateRequest>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _StudyRoomCreateSheetBody(initialMaxPeers: initialMaxPeers),
  );
}

class _StudyRoomCreateSheetBody extends StatefulWidget {
  final int initialMaxPeers;

  const _StudyRoomCreateSheetBody({required this.initialMaxPeers});

  @override
  State<_StudyRoomCreateSheetBody> createState() =>
      _StudyRoomCreateSheetBodyState();
}

class _StudyRoomCreateSheetBodyState extends State<_StudyRoomCreateSheetBody> {
  late final TextEditingController _name;
  late int _maxPeers;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _maxPeers = widget.initialMaxPeers.clamp(2, 8);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      StudyRoomCreateRequest(
        name: resolveStudyRoomName(_name.text),
        maxPeers: _maxPeers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeaderBar(title: '셋 만들기'),
          Text(
            '셋이름(선택)',
            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '우리셋 (변경가능)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Text(
            '인원수 선택',
            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          PeerCountSelectorRow(
            value: _maxPeers,
            onChanged: (n) => setState(() => _maxPeers = n),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _submit,
                child: const Text('만들기'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
