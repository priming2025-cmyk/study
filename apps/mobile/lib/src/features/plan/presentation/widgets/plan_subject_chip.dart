import 'package:flutter/material.dart';

import '../../data/custom_subject_store.dart';

/// 과목 선택 칩 — 탭은 왼쪽(이름), ⋮ 메뉴는 **네모 오른쪽 끝** (편집·삭제).
class PlanSubjectChip extends StatelessWidget {
  final CustomSubject subject;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PlanSubjectChip({
    super.key,
    required this.subject,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = subject.color;

    return Material(
      color: selected ? color.withValues(alpha: 0.14) : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : cs.outlineVariant.withValues(alpha: 0.5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // ── 선택 영역 (과목명) — ⋮과 터치 분리 ─────────────────────
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(11),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 6, backgroundColor: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subject.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? color : cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── ⋮ 메뉴 — 오른쪽 끝 고정 폭, 선택 탭과 겹치지 않음 ───────
            SizedBox(
              width: 36,
              height: double.infinity,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 20,
                splashRadius: 18,
                tooltip: '편집·삭제',
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                position: PopupMenuPosition.under,
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined, size: 20),
                      title: Text('편집'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline_rounded,
                          size: 20, color: cs.error),
                      title: Text('삭제', style: TextStyle(color: cs.error)),
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
