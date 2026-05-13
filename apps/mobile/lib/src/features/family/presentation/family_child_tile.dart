import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/family_repository.dart';
import 'family_format.dart';

class FamilyChildTile extends ConsumerStatefulWidget {
  const FamilyChildTile({super.key, required this.student});

  final LinkedStudent student;

  @override
  ConsumerState<FamilyChildTile> createState() => _FamilyChildTileState();
}

class _FamilyChildTileState extends ConsumerState<FamilyChildTile> {
  bool _open = false;
  Future<List<ChildSessionSummary>>? _sessions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(
          widget.student.displayName?.trim().isNotEmpty == true
              ? widget.student.displayName!
              : '학생',
        ),
        subtitle: Text(
          widget.student.id,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        initiallyExpanded: _open,
        onExpansionChanged: (v) {
          setState(() {
            _open = v;
            if (v && _sessions == null) {
              _sessions = ref
                  .read(familyRepositoryProvider)
                  .fetchChildSessions(widget.student.id);
            }
          });
        },
        children: [
          if (_sessions == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('펼쳐서 불러오기'),
            )
          else
            FutureBuilder<List<ChildSessionSummary>>(
              future: _sessions,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('${snap.error}'),
                  );
                }
                final list = snap.data ?? const [];
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('아직 세션 기록이 없어요.'),
                  );
                }
                return Column(
                  children: list
                      .map(
                        (s) => ListTile(
                          dense: true,
                          title: Text(
                            s.subject?.isNotEmpty == true ? s.subject! : '과목 없음',
                          ),
                          subtitle: Text(
                            '${s.startedAt.year}/${s.startedAt.month}/${s.startedAt.day} · ${formatFocusShort(s.focusedSeconds)}',
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}
