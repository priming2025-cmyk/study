import 'package:flutter/material.dart';
import '../../data/custom_subject_store.dart';
import '../../data/plan_models.dart';
import '../../data/plan_repeat_config.dart';
import 'minute_scroll_picker.dart';
import 'plan_subject_chip.dart';

/// 과목 · 시작시간 · 계획시간 · 반복 — 4탭 계획 추가 시트.
class PlanAddItemSheet extends StatefulWidget {
  final DateTime planDay;
  final PlanItem? editItem;
  final Future<bool> Function()? onDelete;
  final Future<void> Function({
    required String subject,
    required int targetMinutes,
    TimeOfDay? startTime,
    required bool reminderEnabled,
    PlanRepeatConfig? repeat,
  }) onAdd;

  const PlanAddItemSheet({
    super.key,
    required this.planDay,
    required this.onAdd,
    this.editItem,
    this.onDelete,
  });

  @override
  State<PlanAddItemSheet> createState() => _PlanAddItemSheetState();
}

class _PlanAddItemSheetState extends State<PlanAddItemSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _nameCtrl = TextEditingController();

  List<CustomSubject> _subjects = List.from(defaultSubjects);
  String? _selectedName;
  int _selectedColor = 0xFF3B82F6;

  int _startMin = 9 * 60; // 09:00
  int _durationMin = 50;
  PlanRepeatUnit _repeatUnit = PlanRepeatUnit.week;
  int _repeatInterval = 1;
  late Set<int> _weekdays;
  bool _repeatNone = true;
  bool _saving = false;

  bool get _editing => widget.editItem != null;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _weekdays = {widget.planDay.weekday};
    _loadSubjects();
    final e = widget.editItem;
    if (e != null) {
      _selectedName = e.subject;
      _nameCtrl.text = e.subject;
      _durationMin = (e.targetSeconds / 60).round().clamp(5, 240);
      final sched = e.scheduledStartAt?.toLocal();
      if (sched != null) {
        _startMin = sched.hour * 60 + sched.minute;
      }
      _repeatNone = true;
    }
  }

  Future<void> _loadSubjects() async {
    final list = await CustomSubjectStore.load();
    if (mounted) setState(() => _subjects = list);
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  PlanRepeatConfig get _repeatConfig {
    if (_repeatNone || _editing) return const PlanRepeatConfig();
    return PlanRepeatConfig(
      unit: _repeatUnit,
      interval: _repeatInterval,
      weekdays: _weekdays,
    );
  }

  Future<void> _deleteSubjectFromList(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('과목 목록에서 삭제'),
        content: Text('「$name」을(를) 자주 쓰는 과목에서 지울까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await CustomSubjectStore.remove(name);
    await _loadSubjects();
    if (mounted) {
      setState(() {
        if (_selectedName == name) {
          _selectedName = null;
          _nameCtrl.clear();
        }
      });
    }
  }

  Future<void> _deletePlanItem() async {
    final fn = widget.onDelete;
    if (fn == null) return;
    setState(() => _saving = true);
    try {
      final ok = await fn();
      if (ok && mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    final name = (_selectedName ?? _nameCtrl.text).trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('과목을 선택하거나 입력해 주세요')),
      );
      return;
    }
    await CustomSubjectStore.upsert(name, _selectedColor);
    setState(() => _saving = true);
    try {
      final start = TimeOfDay(hour: _startMin ~/ 60, minute: _startMin % 60);
      await widget.onAdd(
        subject: name,
        targetMinutes: _durationMin,
        startTime: start,
        reminderEnabled: true,
        repeat: _repeatConfig,
      );
      if (mounted) Navigator.pop(context);
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
    final bottom = MediaQuery.of(context).padding.bottom;
    final navH = kBottomNavigationBarHeight;
    final sheetH = MediaQuery.of(context).size.height * 0.78;

    return SizedBox(
      height: sheetH,
      child: Material(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing ? '계획 수정' : '새 계획',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _SubjectTab(
                    subjects: _subjects,
                    selected: _selectedName,
                    nameCtrl: _nameCtrl,
                    color: _selectedColor,
                    onSelect: (s) => setState(() {
                      _selectedName = s.name;
                      _selectedColor = s.colorValue;
                      _nameCtrl.text = s.name;
                    }),
                    onColor: (c) => setState(() => _selectedColor = c),
                    onAddCustom: () async {
                      final n = _nameCtrl.text.trim();
                      if (n.isEmpty) return;
                      await CustomSubjectStore.upsert(n, _selectedColor);
                      await _loadSubjects();
                      setState(() {
                        _selectedName = n;
                      });
                    },
                    onDeleteSubject: _deleteSubjectFromList,
                  ),
                  _StartTab(
                    startMin: _startMin,
                    onChanged: (m) => setState(() => _startMin = m),
                  ),
                  _DurationTab(
                    durationMin: _durationMin,
                    onChanged: (m) => setState(() => _durationMin = m),
                  ),
                  _RepeatTab(
                    unit: _repeatUnit,
                    interval: _repeatInterval,
                    weekdays: _weekdays,
                    onUnit: (u) => setState(() {
                      _repeatUnit = u;
                      _repeatNone = false;
                    }),
                    onInterval: (n) => setState(() => _repeatInterval = n),
                    onWeekdayToggle: (d) => setState(() {
                      if (_weekdays.contains(d)) {
                        _weekdays = Set.from(_weekdays)..remove(d);
                      } else {
                        _weekdays = Set.from(_weekdays)..add(d);
                      }
                    }),
                    onNone: () => setState(() => _repeatNone = true),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.only(bottom: bottom + navH * 0.5),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: cs.outlineVariant)),
                color: cs.surface,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    controller: _tab,
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    tabs: const [
                      Tab(text: '과목'),
                      Tab(text: '시작시간'),
                      Tab(text: '계획시간'),
                      Tab(text: '반복'),
                    ],
                  ),
                  if (_editing && widget.onDelete != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _deletePlanItem,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          foregroundColor: cs.error,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text('이 계획 삭제'),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_editing ? '저장' : '계획에 추가'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectTab extends StatelessWidget {
  final List<CustomSubject> subjects;
  final String? selected;
  final TextEditingController nameCtrl;
  final int color;
  final ValueChanged<CustomSubject> onSelect;
  final ValueChanged<int> onColor;
  final VoidCallback onAddCustom;
  final Future<void> Function(String name) onDeleteSubject;

  const _SubjectTab({
    required this.subjects,
    required this.selected,
    required this.nameCtrl,
    required this.color,
    required this.onSelect,
    required this.onColor,
    required this.onAddCustom,
    required this.onDeleteSubject,
  });

  static const _palette = [
    0xFFEF4444,
    0xFFF59E0B,
    0xFF10B981,
    0xFF3B82F6,
    0xFF8B5CF6,
    0xFFEC4899,
    0xFF06B6D4,
    0xFF64748B,
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: subjects.map((s) {
            return PlanSubjectChip(
              subject: s,
              selected: selected == s.name,
              onTap: () => onSelect(s),
              onDelete: () => onDeleteSubject(s.name),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '새 과목',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            FilledButton.tonal(
              onPressed: onAddCustom,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('저장'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _palette.map((c) {
            final sel = color == c;
            return GestureDetector(
              onTap: () => onColor(c),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: sel
                      ? Border.all(color: cs.onSurface, width: 3)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StartTab extends StatelessWidget {
  final int startMin;
  final ValueChanged<int> onChanged;

  const _StartTab({required this.startMin, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: MinuteScrollPicker(
        valueMinutes: startMin,
        minMinutes: 5 * 60,
        maxMinutes: 23 * 60 + 55,
        initialStepMinutes: 5,
        showAmPmToggle: true,
        onChanged: onChanged,
      ),
    );
  }
}

class _DurationTab extends StatelessWidget {
  final int durationMin;
  final ValueChanged<int> onChanged;

  const _DurationTab({required this.durationMin, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: MinuteScrollPicker(
        valueMinutes: durationMin,
        minMinutes: 5,
        maxMinutes: 240,
        initialStepMinutes: 5,
        isDuration: true,
        onChanged: onChanged,
      ),
    );
  }
}

class _RepeatTab extends StatelessWidget {
  final PlanRepeatUnit unit;
  final int interval;
  final Set<int> weekdays;
  final ValueChanged<PlanRepeatUnit> onUnit;
  final ValueChanged<int> onInterval;
  final ValueChanged<int> onWeekdayToggle;
  final VoidCallback onNone;

  const _RepeatTab({
    required this.unit,
    required this.interval,
    required this.weekdays,
    required this.onUnit,
    required this.onInterval,
    required this.onWeekdayToggle,
    required this.onNone,
  });

  static const _days = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('반복 주기', style: tt.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<PlanRepeatUnit>(
          segments: const [
            ButtonSegment(value: PlanRepeatUnit.day, label: Text('일')),
            ButtonSegment(value: PlanRepeatUnit.week, label: Text('주')),
          ],
          selected: {unit},
          onSelectionChanged: (s) => onUnit(s.first),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              onPressed: interval > 1 ? () => onInterval(interval - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Expanded(
              child: Text(
                unit == PlanRepeatUnit.week
                    ? '$interval주마다'
                    : '$interval일마다',
                textAlign: TextAlign.center,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => onInterval(interval + 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        if (unit == PlanRepeatUnit.week) ...[
          const SizedBox(height: 12),
          Text('요일', style: tt.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(7, (i) {
              final d = i + 1;
              final sel = weekdays.contains(d);
              return FilterChip(
                label: Text(_days[i]),
                selected: sel,
                onSelected: (_) => onWeekdayToggle(d),
              );
            }),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: onNone,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: cs.error,
          ),
          child: const Text('반복 안 함'),
        ),
      ],
    );
  }
}
