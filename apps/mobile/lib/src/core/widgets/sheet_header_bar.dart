import 'package:flutter/material.dart';

/// 드래그 핸들이 있는 바텀시트 상단 — 제목 + 닫기(X).
class SheetHeaderBar extends StatelessWidget {
  const SheetHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
    this.padding = const EdgeInsets.fromLTRB(8, 0, 4, 4),
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: tt.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '닫기',
            onPressed: onClose ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
