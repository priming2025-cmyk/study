import 'package:flutter/material.dart';

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
      StudyRoomCreateRequest(name: _name.text.trim(), maxPeers: _maxPeers),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('셋 만들기', style: tt.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '셋 이름 (선택)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          Text('인원수 선택', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in const [2, 3, 4, 5, 6, 7, 8])
                ChoiceChip(
                  label: Text('$n'),
                  selected: _maxPeers == n,
                  onSelected: (_) => setState(() => _maxPeers = n),
                ),
            ],
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
                child: const Text('만들기'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

