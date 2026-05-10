import 'package:flutter/material.dart';

import '../../infra/study_presence.dart';

class OthersStudyingCard extends StatelessWidget {
  final List<PresenceMember> others;

  const OthersStudyingCard({super.key, required this.others});

  @override
  Widget build(BuildContext context) {
    final count = others.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('같이 공부 중', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: Theme.of(context).colorScheme.secondaryContainer,
                  ),
                  child: Text('$count명'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (count == 0)
              Text(
                '지금은 혼자 시작해도 좋아요. 누군가 들어오면 여기서 바로 보여요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: others.take(12).map((m) {
                  return _Chip(
                    subject: m.subject,
                    startedAt: m.startedAt,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String subject;
  final DateTime startedAt;

  const _Chip({required this.subject, required this.startedAt});

  @override
  Widget build(BuildContext context) {
    final minutes = DateTime.now().difference(startedAt).inMinutes;
    final label = subject.trim().isEmpty ? '공부중' : subject.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text('$label · ${minutes}m'),
    );
  }
}

