import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/plan_models.dart';
import 'subject_preset_picker.dart';

/// "과목 + 목표 시간 + (선택) 시작 시각 + 알림" 바텀시트.
/// [planDay]에 해당하는 날짜의 계획에 항목이 추가됩니다(상위에서 주간 바로 날짜 전환).
/// [editItem]이 있으면 같은 필드로 **수정** 모드가 됩니다.
class PlanAddItemSheet extends StatefulWidget {
  final DateTime planDay;
  final List<String> recentSubjects;
  final PlanItem? editItem;
  final Future<void> Function({
    required String subject,
    required int targetMinutes,
    TimeOfDay? startTime,
    required bool reminderEnabled,
  }) onAdd;

  const PlanAddItemSheet({
    super.key,
    required this.planDay,
    required this.onAdd,
    this.recentSubjects = const [],
    this.editItem,
  });

  @override
  State<PlanAddItemSheet> createState() => _PlanAddItemSheetState();
}

class _PlanAddItemSheetState extends State<PlanAddItemSheet> {
  final _textController = TextEditingController();
  final _minutesController = TextEditingController();
  String? _selectedSubject;
  int _targetMinutes = 50;
  TimeOfDay? _startTime;
  bool _reminderEnabled = false;
  bool _saving = false;

  static const _quickMinutes = [25, 30, 50, 60, 90, 120];

  bool get _editing => widget.editItem != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editItem;
    if (e != null) {
      _textController.text = e.subject;
      _selectedSubject = e.subject;
      _targetMinutes = (e.targetSeconds / 60).round().clamp(1, 960);
      final sched = e.scheduledStartAt;
      if (sched != null) {
        final local = sched.toLocal();
        _startTime = TimeOfDay(hour: local.hour, minute: local.minute);
        _reminderEnabled = e.reminderEnabled;
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _onPresetSelected(String s) {
    setState(() {
      _selectedSubject = s;
      _textController.text = s;
    });
  }

  void _onMinutesChip(int m) {
    setState(() {
      _targetMinutes = m;
      _minutesController.text = '';
    });
  }

  Future<void> _pickStartTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (t != null) {
      setState(() {
        _startTime = t;
        _reminderEnabled = true;
      });
    }
  }

  Future<void> _submit() async {
    final customMinutes = int.tryParse(_minutesController.text.trim());
    var minutes = _targetMinutes;
    if (customMinutes != null && customMinutes > 0) {
      minutes = customMinutes.clamp(1, 960);
    }

    final subject = _textController.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('과목명을 입력하거나 선택해 주세요')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onAdd(
        subject: subject,
        targetMinutes: minutes,
        startTime: _startTime,
        reminderEnabled: _startTime != null && _reminderEnabled,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editing ? '저장 실패: $e' : '추가 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final dayLabel = DateFormat.yMMMEd('ko').format(widget.planDay);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _editing ? '과목 수정' : '과목 추가',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              dayLabel,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              autofocus: false,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _selectedSubject = null),
              decoration: InputDecoration(
                labelText: '과목명 직접 입력 또는 아래에서 선택',
                prefixIcon: _selectedSubject != null
                    ? Icon(Icons.circle,
                        size: 12, color: subjectColor(_selectedSubject!))
                    : const Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 14),
            SubjectPresetPicker(
              selected: _selectedSubject,
              onSelect: _onPresetSelected,
            ),
            if (widget.recentSubjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('최근',
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.recentSubjects
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(s, style: const TextStyle(fontSize: 12)),
                            onPressed: () => _onPresetSelected(s),
                            avatar: Icon(Icons.history,
                                size: 14, color: cs.onSurfaceVariant),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('목표 공부 시간', style: tt.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _quickMinutes.map((m) {
                        final sel =
                            _minutesController.text.isEmpty && _targetMinutes == m;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('$m분', style: const TextStyle(fontSize: 12)),
                            selected: sel,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => _onMinutesChip(m),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 88,
                  child: TextField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '직접',
                      suffixText: '분',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('시작 시각(선택)', style: tt.labelLarge),
            const SizedBox(height: 6),
            Text(
              '날짜는 위에 표시된 계획 날짜에 맞춰집니다. 주간 바에서 다른 날을 고른 뒤 추가하세요.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStartTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      _startTime == null
                          ? '시간 선택'
                          : _startTime!.format(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_startTime != null)
                  IconButton(
                    tooltip: '시작 시각 지우기',
                    onPressed: () => setState(() {
                      _startTime = null;
                      _reminderEnabled = false;
                    }),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            if (_startTime != null) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('이 시간에 알림'),
                subtitle: const Text('앱/브라우저에서 로컬 알림으로 알려 드려요.'),
                value: _reminderEnabled,
                onChanged: (v) => setState(() => _reminderEnabled = v),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_editing ? '변경 저장' : '계획에 추가'),
            ),
          ],
        ),
      ),
    );
  }
}
