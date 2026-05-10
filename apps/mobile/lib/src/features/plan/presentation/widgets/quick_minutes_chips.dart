import 'package:flutter/material.dart';

class QuickMinutesChips extends StatelessWidget {
  final int selectedMinutes;
  final ValueChanged<int> onSelected;

  const QuickMinutesChips({
    super.key,
    required this.selectedMinutes,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [25, 50, 60, 90].map((m) {
        final selected = selectedMinutes == m;
        return ChoiceChip(
          label: Text('$m분'),
          selected: selected,
          onSelected: (_) => onSelected(m),
        );
      }).toList(),
    );
  }
}

