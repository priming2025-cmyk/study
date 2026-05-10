import 'package:flutter/material.dart';

class RecentSubjectsRow extends StatelessWidget {
  final List<String> subjects;
  final ValueChanged<String> onTap;

  const RecentSubjectsRow({
    super.key,
    required this.subjects,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('최근 과목', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: subjects
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(s),
                      onPressed: () => onTap(s),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

