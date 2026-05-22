import 'package:flutter/material.dart';

/// 몇 시부터 몇 시까지 공부할지 설정하는 바텀시트.
class StudyTimeRangeSheet extends StatefulWidget {
  final String subject;
  final TimeOfDay? initialStart;
  final TimeOfDay? initialEnd;

  const StudyTimeRangeSheet({
    super.key,
    required this.subject,
    this.initialStart,
    this.initialEnd,
  });

  static Future<({TimeOfDay start, TimeOfDay end, int targetMinutes})?> show(
    BuildContext context, {
    required String subject,
    TimeOfDay? initialStart,
    TimeOfDay? initialEnd,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StudyTimeRangeSheet(
        subject: subject,
        initialStart: initialStart,
        initialEnd: initialEnd,
      ),
    );
  }

  @override
  State<StudyTimeRangeSheet> createState() => _StudyTimeRangeSheetState();
}

class _StudyTimeRangeSheetState extends State<StudyTimeRangeSheet> {
  TimeOfDay? _start;
  TimeOfDay? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart ?? TimeOfDay.now();
    _end = widget.initialEnd ??
        TimeOfDay(
          hour: (TimeOfDay.now().hour + 1) % 24,
          minute: TimeOfDay.now().minute,
        );
  }

  int _durationMinutes() {
    if (_start == null || _end == null) return 0;
    final s = _start!.hour * 60 + _start!.minute;
    var e = _end!.hour * 60 + _end!.minute;
    if (e <= s) e += 24 * 60;
    return e - s;
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _start ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _start = t);
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _end ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _end = t);
  }

  void _save() {
    if (_start == null || _end == null) return;
    final mins = _durationMinutes();
    if (mins < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 5분 이상으로 설정해 주세요')),
      );
      return;
    }
    Navigator.of(context).pop((
      start: _start!,
      end: _end!,
      targetMinutes: mins.clamp(5, 240),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mins = _durationMinutes();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.subject,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '공부 시간 계획',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _TimeTile(
                  label: '시작',
                  time: _start,
                  onTap: _pickStart,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward_rounded,
                    color: cs.onSurfaceVariant, size: 18),
              ),
              Expanded(
                child: _TimeTile(
                  label: '종료',
                  time: _end,
                  onTap: _pickEnd,
                ),
              ),
            ],
          ),
          if (mins > 0) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                '총 ${mins ~/ 60 > 0 ? '${mins ~/ 60}시간 ' : ''}${mins % 60}분',
                style: tt.titleSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(Icons.access_time_rounded, size: 22, color: cs.primary),
              const SizedBox(height: 6),
              Text(label,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                time?.format(context) ?? '--:--',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
