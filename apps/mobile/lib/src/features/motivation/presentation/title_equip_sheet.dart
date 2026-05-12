import 'package:flutter/material.dart';

import '../data/motivation_repository.dart';

/// 획득한 칭호 목록에서 착용할 칭호를 고릅니다.
Future<void> showTitleEquipBottomSheet(
  BuildContext context,
  MotivationRepository repo,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: repo.myUnlockedTitles(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final rows = snap.data!;
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('아직 획득한 칭호가 없어요. 레벨을 올려 보세요.'),
              );
            }
            return ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('칭호 착용', style: Theme.of(context).textTheme.titleMedium),
                ),
                ...rows.map((r) {
                  final nested = r['titles'] as Map<String, dynamic>?;
                  final titleId = r['title_id'] as String? ?? nested?['id'] as String?;
                  final nameKo = nested?['name_ko'] as String? ?? '칭호';
                  final minLv = (nested?['min_level'] as num?)?.toInt() ?? 0;
                  return ListTile(
                    title: Text(nameKo),
                    subtitle: Text('필요 Lv.$minLv'),
                    onTap: titleId == null
                        ? null
                        : () async {
                            try {
                              await repo.equipTitle(titleId);
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('칭호를 적용했어요.')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('적용 실패: $e')),
                                );
                              }
                            }
                          },
                  );
                }),
              ],
            );
          },
        ),
      );
    },
  );
}
