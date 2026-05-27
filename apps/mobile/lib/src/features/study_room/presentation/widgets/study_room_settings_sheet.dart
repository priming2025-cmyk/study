import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_picker_row.dart';
import '../../../../core/widgets/sheet_header_bar.dart';
import '../../../session/presentation/widgets/engaged_sensitivity_metro_card.dart';
import '../../domain/study_room_default_name.dart';
import 'peer_count_selector_row.dart';

/// 방 설정(셋 이름/인원수) + 집중민감도 + 색 테마.
///
/// - 방장만 `셋 이름/인원수` 수정 가능
/// - 집중민감도·색 테마는 항상 조절 가능
class StudyRoomSettingsSheet extends StatefulWidget {
  final bool isRoomHost;
  final String initialRoomName;
  final int initialMaxPeers;
  final int engagedMinScore;
  final Future<bool> Function(String name, int maxPeers) onUpdateRoomSettings;
  final Future<void> Function(int value) onSelectSensitivity;

  const StudyRoomSettingsSheet({
    super.key,
    required this.isRoomHost,
    required this.initialRoomName,
    required this.initialMaxPeers,
    required this.engagedMinScore,
    required this.onUpdateRoomSettings,
    required this.onSelectSensitivity,
  });

  @override
  State<StudyRoomSettingsSheet> createState() =>
      _StudyRoomSettingsSheetState();
}

class _StudyRoomSettingsSheetState extends State<StudyRoomSettingsSheet> {
  late final TextEditingController _nameCtrl;
  late int _maxPeers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: displayRoomNameForEdit(widget.initialRoomName),
    );
    _maxPeers = widget.initialMaxPeers.clamp(2, 8);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyRoomSettings() async {
    if (!widget.isRoomHost) return;
    setState(() => _saving = true);
    final ok = await widget.onUpdateRoomSettings(_nameCtrl.text, _maxPeers);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('방 설정 변경에 실패했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    final canEdit = widget.isRoomHost && !_saving;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeaderBar(title: '셋 설정'),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.isRoomHost) ...[
                      Text(
                        '셋이름(변경)',
                        style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        enabled: canEdit,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: '비우면 우리셋',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '인원수 선택',
                        style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      PeerCountSelectorRow(
                        value: _maxPeers,
                        enabled: canEdit,
                        onChanged: canEdit
                            ? (n) => setState(() => _maxPeers = n)
                            : null,
                      ),
                      const SizedBox(height: 20),
                    ],
                    EngagedSensitivityMetroCard(
                      engagedMinScore: widget.engagedMinScore,
                      onSelect: widget.onSelectSensitivity,
                    ),
                    const SizedBox(height: 16),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(14, 14, 14, 16),
                        child: AppThemePickerRow(),
                      ),
                    ),
                    if (widget.isRoomHost) ...[
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: canEdit ? _applyRoomSettings : null,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('적용'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
