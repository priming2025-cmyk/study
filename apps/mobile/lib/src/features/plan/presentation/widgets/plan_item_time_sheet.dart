import 'package:flutter/material.dart';

import '../../data/plan_models.dart';
import 'minute_scroll_picker.dart';
import 'plan_time_utils.dart';

/// 계획 카드 시계 버튼 — 시작 시각 + 소요 시간 (스크롤).
class PlanItemTimeSheet extends StatefulWidget {
  final PlanItem item;
  final Future<void> Function({
    required int targetMinutes,
    required TimeOfDay? startTime,
    required bool reminderEnabled,
  }) onSave;

  const PlanItemTimeSheet({
    super.key,
    required this.item,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required PlanItem item,
    required Future<void> Function({
      required int targetMinutes,
      required TimeOfDay? startTime,
      required bool reminderEnabled,
    }) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PlanItemTimeSheet(item: item, onSave: onSave),
    );
  }

  @override
  State<PlanItemTimeSheet> createState() => _PlanItemTimeSheetState();
}

class _PlanItemTimeSheetState extends State<PlanItemTimeSheet> {
  late int _durationMin;
  late int _startMin;
  bool _startUnset = false;
  bool _durationUnset = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _durationUnset = widget.item.targetSeconds <= 0;
    _durationMin = _durationUnset
        ? 50
        : (widget.item.targetSeconds / 60).round().clamp(5, 240);
    final sched = widget.item.scheduledStartAt?.toLocal();
    _startUnset = sched == null;
    if (sched != null) {
      _startMin = sched.hour * 60 + sched.minute;
    } else {
      _startMin = nearestFiveMinuteOfDay(DateTime.now());
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(
        targetMinutes: _durationUnset ? 0 : _durationMin,
        startTime: _startUnset
            ? null
            : TimeOfDay(hour: _startMin ~/ 60, minute: _startMin % 60),
        reminderEnabled: !_startUnset,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.item.subject, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text('시간 설정', style: tt.bodySmall),
          const SizedBox(height: 12),
          MinuteScrollPicker(
            sectionLabel: '시작',
            valueMinutes: _startMin,
            minMinutes: 5 * 60,
            maxMinutes: 23 * 60 + 55,
            initialStepMinutes: 5,
            compact: true,
            showUnsetOption: true,
            isUnset: _startUnset,
            onUnsetTap: () => setState(() => _startUnset = true),
            onChanged: (m) => setState(() {
              _startMin = m;
              _startUnset = false;
            }),
          ),
          const SizedBox(height: 10),
          MinuteScrollPicker(
            sectionLabel: '계획시간',
            valueMinutes: _durationMin,
            minMinutes: 5,
            maxMinutes: 240,
            initialStepMinutes: 5,
            isDuration: true,
            compact: true,
            showUnsetOption: true,
            isUnset: _durationUnset,
            onUnsetTap: () => setState(() => _durationUnset = true),
            onChanged: (m) => setState(() {
              _durationMin = m;
              _durationUnset = false;
            }),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('저장'),
          ),
        ],
      ),
    );
  }
}
