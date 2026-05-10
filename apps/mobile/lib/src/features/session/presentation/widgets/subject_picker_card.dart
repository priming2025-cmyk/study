import 'package:flutter/material.dart';

import '../../../plan/data/plan_models.dart';

class SubjectPickerCard extends StatelessWidget {
  final TodayPlan? todayPlan;
  final String? selectedPlanItemId;
  final ValueChanged<PlanItem> onSelected;
  final TextEditingController newSubjectController;
  final int quickMinutes;
  final ValueChanged<int> onQuickMinutesChanged;
  final VoidCallback onAddAndSelect;

  const SubjectPickerCard({
    super.key,
    required this.todayPlan,
    required this.selectedPlanItemId,
    required this.onSelected,
    required this.newSubjectController,
    required this.quickMinutes,
    required this.onQuickMinutesChanged,
    required this.onAddAndSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = todayPlan?.items ?? const <PlanItem>[];
    final hasPlan = items.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('오늘 과목', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (hasPlan) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((e) {
                  final selected = e.id == selectedPlanItemId;
                  return ChoiceChip(
                    label: Text(e.subject),
                    selected: selected,
                    onSelected: (_) => onSelected(e),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                '시작을 누르면 선택된 과목에 공부시간이 자동으로 누적돼요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ] else ...[
              Text(
                '오늘 계획된 과목이 없어요. 1개만 입력하면 바로 시작할 수 있어요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newSubjectController,
                decoration: const InputDecoration(labelText: '과목/할 일'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [25, 50, 60].map((m) {
                  return ChoiceChip(
                    label: Text('$m분'),
                    selected: quickMinutes == m,
                    onSelected: (_) => onQuickMinutesChanged(m),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAddAndSelect,
                  icon: const Icon(Icons.add),
                  label: const Text('과목 추가 후 시작 준비'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

