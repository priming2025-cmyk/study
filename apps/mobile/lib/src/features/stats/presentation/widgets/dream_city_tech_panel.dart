import 'package:flutter/material.dart';

import '../../domain/dream_city_state.dart';
import '../../domain/dream_city_tech_tree.dart';

/// 테크트리·다음 건설 목표 패널.
class DreamCityTechPanel extends StatelessWidget {
  final DreamCityState state;

  const DreamCityTechPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('직업 테크트리',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          '공부 블럭으로 건물이 해금되고, 선행 건물이 있어야 다음 단계가 열려요.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        ...DreamCityBranch.values.map((branch) {
          final defs = dreamCityByBranch(branch);
          final built = defs.where((d) => state.placed.any((p) => p.def.id == d.id)).length;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              leading: Text(branch.emoji, style: const TextStyle(fontSize: 22)),
              title: Text(branch.labelKo,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text('$built / ${defs.length} 건설'),
              children: defs.map((d) {
                final done = state.placed.any((p) => p.def.id == d.id);
                final locked = state.blockCount < d.blockCost;
                final prereq = d.requiresIds
                    .map((id) => dreamCityDefById(id)?.nameKo ?? id)
                    .join(', ');
                return ListTile(
                  dense: true,
                  leading: Text(d.emoji, style: const TextStyle(fontSize: 20)),
                  title: Text(
                    '${d.nameKo} (T${d.tier})',
                    style: TextStyle(
                      fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                      color: done ? cs.primary : null,
                    ),
                  ),
                  subtitle: Text(
                    done
                        ? d.kidDreamLine
                        : locked
                            ? '블럭 ${d.blockCost}개 필요'
                            : prereq.isEmpty
                                ? '건설 가능!'
                                : '선행: $prereq',
                    style: tt.labelSmall,
                  ),
                  trailing: done
                      ? Icon(Icons.check_circle, color: cs.primary, size: 20)
                      : locked
                          ? Text('${d.blockCost - state.blockCount}',
                              style: tt.labelSmall)
                          : const Icon(Icons.lock_open, size: 18),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }
}
