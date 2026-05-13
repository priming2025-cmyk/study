import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../plan/data/plan_models.dart';
import '../../../plan/presentation/widgets/subject_preset_picker.dart';
import 'session_plan_subject_tile.dart';

/// 집중 세션에서 오늘 과목을 고르거나, 계획 편집과 비슷한 흐름으로 빠르게 추가합니다.
class SubjectPickerCard extends StatefulWidget {
  final TodayPlan? todayPlan;
  final String? selectedPlanItemId;
  final ValueChanged<PlanItem> onSelected;
  final List<String> recentSubjects;
  final Future<void> Function({
    required String subject,
    required int targetMinutes,
  }) onQuickAdd;
  final VoidCallback onOpenAdvancedAdd;
  final void Function(PlanItem item) onEditItem;
  final Future<void> Function(PlanItem item) onDeleteItem;

  const SubjectPickerCard({
    super.key,
    required this.todayPlan,
    required this.selectedPlanItemId,
    required this.onSelected,
    required this.recentSubjects,
    required this.onQuickAdd,
    required this.onOpenAdvancedAdd,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  @override
  State<SubjectPickerCard> createState() => _SubjectPickerCardState();
}

class _SubjectPickerCardState extends State<SubjectPickerCard> {
  final _subjectCtrl = TextEditingController();
  final _minutesCtrl = TextEditingController();
  String? _selectedPreset;
  int _targetMinutes = 50;
  bool _adding = false;

  static const _quickMinutes = [25, 30, 50, 60, 90, 120];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  void _onPreset(String s) {
    setState(() {
      _selectedPreset = s;
      _subjectCtrl.text = s;
    });
  }

  void _onMinutesChip(int m) {
    setState(() {
      _targetMinutes = m;
      _minutesCtrl.clear();
    });
  }

  Future<void> _submitQuickAdd() async {
    final custom = int.tryParse(_minutesCtrl.text.trim());
    var minutes = _targetMinutes;
    if (custom != null && custom > 0) minutes = custom.clamp(1, 960);

    final subject = _subjectCtrl.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('과목명을 입력하거나 아래에서 선택해 주세요')),
      );
      return;
    }

    setState(() => _adding = true);
    try {
      await widget.onQuickAdd(subject: subject, targetMinutes: minutes);
      if (mounted) {
        _subjectCtrl.clear();
        _minutesCtrl.clear();
        _selectedPreset = null;
        _targetMinutes = 50;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추가 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.todayPlan?.items ?? const <PlanItem>[];
    final hasPlan = items.isNotEmpty;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('오늘 집중할 과목', style: tt.titleMedium),
                      const SizedBox(height: 4),
                      if (!hasPlan)
                        Text(
                          '아래에서 빠르게 추가하거나, 전체 옵션에서 시작 시각·알림까지 설정할 수 있어요.',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                if (hasPlan)
                  TextButton.icon(
                    onPressed: widget.onOpenAdvancedAdd,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('추가'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasPlan) ...[
              ...items.map((e) => SessionPlanSubjectTile(
                    item: e,
                    selected: e.id == widget.selectedPlanItemId,
                    onTap: () => widget.onSelected(e),
                    onEdit: () => widget.onEditItem(e),
                    onDelete: () => widget.onDeleteItem(e),
                  )),
            ] else ...[
              TextField(
                controller: _subjectCtrl,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _selectedPreset = null),
                decoration: InputDecoration(
                  labelText: '과목명',
                  hintText: '직접 입력하거나 아래에서 선택',
                  prefixIcon: _selectedPreset != null
                      ? Icon(Icons.circle, size: 12, color: subjectColor(_selectedPreset!))
                      : const Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 12),
              SubjectPresetPicker(
                selected: _selectedPreset,
                onSelect: _onPreset,
              ),
              if (widget.recentSubjects.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('최근', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
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
                              onPressed: () => _onPreset(s),
                              avatar: Icon(Icons.history, size: 14, color: cs.onSurfaceVariant),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text('목표 공부 시간', style: tt.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _quickMinutes.map((m) {
                          final sel = _minutesCtrl.text.isEmpty && _targetMinutes == m;
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
                      controller: _minutesCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '직접',
                        suffixText: '분',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _adding ? null : _submitQuickAdd,
                      icon: _adding
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : const Icon(Icons.play_arrow_outlined),
                      label: Text(_adding ? '추가 중…' : '계획에 넣고 이 과목 선택'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: widget.onOpenAdvancedAdd,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('시작 시각·알림까지 설정'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
