import 'package:flutter/material.dart';
import '../../data/custom_subject_store.dart';
import '../../data/plan_models.dart';
import '../../data/plan_repeat_config.dart';
import 'minute_scroll_picker.dart';
import 'plan_subject_chip.dart';
import 'plan_time_utils.dart';

/// 과목 · 시간계획 · 반복 — 3탭 계획 추가 시트.
class PlanAddItemSheet extends StatefulWidget {
  final DateTime planDay;
  final List<PlanItem> existingItems;
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
    this.existingItems = const [],
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

  late int _startMin;
  late int _durationMin;
  PlanRepeatUnit _repeatUnit = PlanRepeatUnit.week;
  int _repeatInterval = 1;
  late Set<int> _weekdays;
  bool _repeatNone = true;
  bool _saving = false;

  bool get _editing => widget.editItem != null;

  String get _sheetTitle {
    if (_editing) return '계획 수정';
    return switch (_tab.index) {
      0 => '과목',
      1 => '시간계획',
      2 => '반복',
      _ => '새 계획',
    };
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tab.indexIsChanging) setState(() {});
      });
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
      } else {
        _startMin = suggestPlanStartMinutes(widget.existingItems, DateTime.now());
      }
      _repeatNone = true;
    } else {
      _startMin = suggestPlanStartMinutes(widget.existingItems, DateTime.now());
      _durationMin = suggestPlanDurationMinutes(widget.existingItems) ?? 50;
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
                      _sheetTitle,
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
                      await _loadSubjects();
                      if (mounted && n.isNotEmpty) {
                        setState(() => _selectedName = n);
                      }
                    },
                    onDeleteSubject: _deleteSubjectFromList,
                  ),
                  _TimePlanTab(
                    startMin: _startMin,
                    durationMin: _durationMin,
                    onStartChanged: (m) => setState(() => _startMin = m),
                    onDurationChanged: (m) => setState(() => _durationMin = m),
                  ),
                  _RepeatTab(
                    repeatNone: _repeatNone,
                    unit: _repeatUnit,
                    interval: _repeatInterval,
                    weekdays: _weekdays,
                    onPickInterval: () async {
                      final picked = await _RepeatIntervalSheet.show(
                        context,
                        interval: _repeatInterval,
                        unit: _repeatUnit,
                      );
                      if (picked == null || !mounted) return;
                      setState(() {
                        _repeatInterval = picked.$1;
                        _repeatUnit = picked.$2;
                        _repeatNone = false;
                      });
                    },
                    onWeekdayToggle: (d) => setState(() {
                      if (_weekdays.contains(d)) {
                        if (_weekdays.length > 1) {
                          _weekdays = Set.from(_weekdays)..remove(d);
                        }
                      } else {
                        _weekdays = Set.from(_weekdays)..add(d);
                      }
                      _repeatNone = false;
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
                      Tab(text: '시간계획'),
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

class _SubjectTab extends StatefulWidget {
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

  @override
  State<_SubjectTab> createState() => _SubjectTabState();
}

class _SubjectTabState extends State<_SubjectTab> {
  bool _showNewSubjectForm = false;
  String? _editingSubjectName;

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

  void _openNewSubjectForm() {
    widget.nameCtrl.clear();
    setState(() {
      _editingSubjectName = null;
      _showNewSubjectForm = true;
    });
  }

  void _openEditSubjectForm(CustomSubject s) {
    widget.nameCtrl.text = s.name;
    widget.onColor(s.colorValue);
    setState(() {
      _editingSubjectName = s.name;
      _showNewSubjectForm = true;
    });
  }

  void _closeNewSubjectForm({bool clearName = true}) {
    if (clearName) widget.nameCtrl.clear();
    setState(() {
      _showNewSubjectForm = false;
      _editingSubjectName = null;
    });
  }

  Future<void> _saveSubjectForm() async {
    final n = widget.nameCtrl.text.trim();
    if (n.isEmpty) return;
    if (_editingSubjectName != null) {
      await CustomSubjectStore.rename(_editingSubjectName!, n, widget.color);
    } else {
      await CustomSubjectStore.upsert(n, widget.color);
    }
    widget.onAddCustom();
    _closeNewSubjectForm(clearName: false);
  }

  /// 국어·영어·수학·과학·사회를 항상 앞에 두고, 나머지는 이름순.
  List<CustomSubject> _sortedSubjects() {
    final defaultNames = defaultSubjects.map((s) => s.name).toList();
    final byName = {for (final s in widget.subjects) s.name: s};
    final ordered = <CustomSubject>[];
    for (final name in defaultNames) {
      final s = byName.remove(name);
      if (s != null) ordered.add(s);
    }
    final rest = byName.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return [...ordered, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sorted = _sortedSubjects();
    final screenW = MediaQuery.sizeOf(context).width;
    // 좁은 화면은 2열 → 과목명·⋮이 한 줄에 들어갈 폭 확보
    final crossAxisCount = screenW >= 520 ? 3 : 2;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: crossAxisCount == 3 ? 2.55 : 3.0,
          ),
          itemCount: sorted.length,
          itemBuilder: (context, i) {
            final s = sorted[i];
            return PlanSubjectChip(
              subject: s,
              selected: widget.selected == s.name,
              onTap: () => widget.onSelect(s),
              onEdit: () => _openEditSubjectForm(s),
              onDelete: () => widget.onDeleteSubject(s.name),
            );
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: Icon(Icons.add_rounded, size: 18, color: cs.primary),
            label: Text(
              '새과목',
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
            side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
            onPressed: _openNewSubjectForm,
          ),
        ),
        if (_showNewSubjectForm) ...[
          const SizedBox(height: 16),
          Text(
            _editingSubjectName != null ? '과목 편집' : '새 과목 만들기',
            style: tt.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: 3,
                child: TextField(
                  controller: widget.nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '새 과목 이름',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                tooltip: '닫기',
                icon: const Icon(Icons.close),
                onPressed: _closeNewSubjectForm,
              ),
              FilledButton.tonal(
                onPressed: _saveSubjectForm,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              final sel = widget.color == c;
              return GestureDetector(
                onTap: () => widget.onColor(c),
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
      ],
    );
  }
}

class _TimePlanTab extends StatelessWidget {
  final int startMin;
  final int durationMin;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onDurationChanged;

  const _TimePlanTab({
    required this.startMin,
    required this.durationMin,
    required this.onStartChanged,
    required this.onDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('시작 시간', style: tt.titleSmall),
        const SizedBox(height: 8),
        MinuteScrollPicker(
          valueMinutes: startMin,
          minMinutes: 5 * 60,
          maxMinutes: 23 * 60 + 55,
          initialStepMinutes: 5,
          onChanged: onStartChanged,
        ),
        const SizedBox(height: 28),
        Text('계획 시간', style: tt.titleSmall),
        const SizedBox(height: 8),
        MinuteScrollPicker(
          valueMinutes: durationMin,
          minMinutes: 5,
          maxMinutes: 240,
          initialStepMinutes: 5,
          isDuration: true,
          onChanged: onDurationChanged,
        ),
      ],
    );
  }
}

class _RepeatTab extends StatelessWidget {
  final bool repeatNone;
  final PlanRepeatUnit unit;
  final int interval;
  final Set<int> weekdays;
  final VoidCallback onPickInterval;
  final ValueChanged<int> onWeekdayToggle;
  final VoidCallback onNone;

  const _RepeatTab({
    required this.repeatNone,
    required this.unit,
    required this.interval,
    required this.weekdays,
    required this.onPickInterval,
    required this.onWeekdayToggle,
    required this.onNone,
  });

  static const _days = ['월', '화', '수', '목', '금', '토', '일'];

  String get _intervalLabel => switch (unit) {
        PlanRepeatUnit.week => '$interval주마다',
        PlanRepeatUnit.day => '$interval일마다',
        _ => '1주마다',
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final showWeekdays = !repeatNone && unit == PlanRepeatUnit.week;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('반복 주기', style: tt.titleSmall),
            const Spacer(),
            Material(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onPickInterval,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        repeatNone ? '1주마다' : _intervalLabel,
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (showWeekdays) ...[
          const SizedBox(height: 16),
          Row(
            children: List.generate(7, (i) {
              final d = i + 1;
              final sel = weekdays.contains(d);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                  child: Material(
                    color: sel
                        ? cs.surfaceContainerHigh
                        : cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => onWeekdayToggle(d),
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 34,
                        child: Center(
                          child: Text(
                            _days[i],
                            style: tt.labelMedium?.copyWith(
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500,
                              color: sel
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: onNone,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            foregroundColor: cs.onSurface,
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: const Text('반복 안 함'),
        ),
      ],
    );
  }
}

/// 반복 주기 선택 (숫자 휠 + 일/주 단위).
class _RepeatIntervalSheet extends StatefulWidget {
  final int interval;
  final PlanRepeatUnit unit;

  const _RepeatIntervalSheet({
    required this.interval,
    required this.unit,
  });

  static Future<(int, PlanRepeatUnit)?> show(
    BuildContext context, {
    required int interval,
    required PlanRepeatUnit unit,
  }) {
    return showModalBottomSheet<(int, PlanRepeatUnit)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => _RepeatIntervalSheet(interval: interval, unit: unit),
    );
  }

  @override
  State<_RepeatIntervalSheet> createState() => _RepeatIntervalSheetState();
}

class _RepeatIntervalSheetState extends State<_RepeatIntervalSheet> {
  static const _maxInterval = 12;
  late FixedExtentScrollController _numCtrl;
  late FixedExtentScrollController _unitCtrl;
  late int _interval;
  late PlanRepeatUnit _unit;

  @override
  void initState() {
    super.initState();
    _interval = widget.interval.clamp(1, _maxInterval);
    _unit = widget.unit == PlanRepeatUnit.day
        ? PlanRepeatUnit.day
        : PlanRepeatUnit.week;
    _numCtrl = FixedExtentScrollController(initialItem: _interval - 1);
    _unitCtrl = FixedExtentScrollController(
      initialItem: _unit == PlanRepeatUnit.day ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _numCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '반복 주기',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: _PickerColumn(
                    controller: _numCtrl,
                    labels: List.generate(
                      _maxInterval,
                      (i) => '${i + 1}',
                    ),
                    onSelected: (i) => _interval = i + 1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerColumn(
                    controller: _unitCtrl,
                    labels: const ['일', '주'],
                    onSelected: (i) {
                      _unit = i == 0
                          ? PlanRepeatUnit.day
                          : PlanRepeatUnit.week;
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: cs.onSurface,
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, (_interval, _unit)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('완료'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickerColumn extends StatelessWidget {
  final FixedExtentScrollController controller;
  final List<String> labels;
  final ValueChanged<int> onSelected;

  const _PickerColumn({
    required this.controller,
    required this.labels,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 44,
          perspective: 0.003,
          diameterRatio: 1.4,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onSelected,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: labels.length,
            builder: (context, i) {
              final sel =
                  controller.hasClients && controller.selectedItem == i;
              return Center(
                child: Text(
                  labels[i],
                  style: (sel ? tt.titleMedium : tt.bodyMedium)?.copyWith(
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w400,
                    color: sel ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
