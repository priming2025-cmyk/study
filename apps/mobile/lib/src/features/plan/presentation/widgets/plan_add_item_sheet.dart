import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/plan_models.dart';
import 'station_time_picker.dart';
import 'subject_preset_picker.dart';

/// "과목 + 목표 시간(지하철 정류장 방식) + (선택) 시작 시각 + 알림" 바텀시트.
/// [editItem]이 있으면 수정 모드가 됩니다.
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
  String? _selectedSubject;
  int _targetMinutes = 60;
  TimeOfDay? _startTime;
  bool _reminderEnabled = false;
  bool _saving = false;

  bool get _editing => widget.editItem != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editItem;
    if (e != null) {
      _textController.text = e.subject;
      _selectedSubject = e.subject;
      _targetMinutes = (e.targetSeconds / 60).round().clamp(5, 240);
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
    super.dispose();
  }

  void _onPresetSelected(String s) {
    setState(() {
      _selectedSubject = s;
      _textController.text = s;
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

  void _clearStartTime() {
    setState(() {
      _startTime = null;
      _reminderEnabled = false;
    });
  }

  Future<void> _submit() async {
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
        targetMinutes: _targetMinutes,
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
            // 드래그 핸들
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
            // 제목 + 날짜
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editing ? '과목 수정' : '과목 추가',
                        style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayLabel,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                // 시작 시각 아이콘 버튼 (우상단)
                _StartTimeButton(
                  startTime: _startTime,
                  onPick: _pickStartTime,
                  onClear: _clearStartTime,
                  reminderEnabled: _reminderEnabled,
                  onReminderChanged: (v) =>
                      setState(() => _reminderEnabled = v),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 과목 입력 ──
            TextField(
              controller: _textController,
              autofocus: false,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _selectedSubject = null),
              decoration: InputDecoration(
                labelText: '과목명 직접 입력 또는 아래에서 선택',
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary, width: 2),
                ),
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
              const SizedBox(height: 10),
              Text('최근',
                  style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.recentSubjects
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(s,
                                style: const TextStyle(fontSize: 12)),
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

            // ── 목표 공부 시간 (지하철 정류장) ──
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.directions_subway_rounded,
                    size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text('목표 공부 시간', style: tt.labelLarge),
                const Spacer(),
                Text(
                  '30분 단위 정류장 · 5분씩 조정 가능',
                  style: tt.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StationTimePicker(
              initialMinutes: _targetMinutes,
              onChanged: (m) => setState(() => _targetMinutes = m),
            ),

            const SizedBox(height: 24),
            // 저장 버튼
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _editing ? '변경 저장' : '계획에 추가',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 시작 시각 아이콘 버튼 (우상단)
// ─────────────────────────────────────────────
class _StartTimeButton extends StatelessWidget {
  final TimeOfDay? startTime;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final bool reminderEnabled;
  final ValueChanged<bool> onReminderChanged;

  const _StartTimeButton({
    required this.startTime,
    required this.onPick,
    required this.onClear,
    required this.reminderEnabled,
    required this.onReminderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasTime = startTime != null;

    return GestureDetector(
      onTap: onPick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasTime
              ? cs.primaryContainer
              : cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: hasTime
              ? Border.all(color: cs.primary.withValues(alpha: 0.3), width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 20,
              color: hasTime ? cs.primary : cs.onSurfaceVariant,
            ),
            if (hasTime) ...[
              const SizedBox(width: 6),
              Text(
                startTime!.format(context),
                style: tt.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(width: 6),
              Text(
                '시작 시각',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
