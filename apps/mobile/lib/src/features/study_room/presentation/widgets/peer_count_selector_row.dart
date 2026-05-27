import 'package:flutter/material.dart';

/// 인원수 2~8 — 한 줄, 선택 시 색만 변경 (체크 아이콘 없음).
class PeerCountSelectorRow extends StatelessWidget {
  const PeerCountSelectorRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final bool enabled;

  static const _counts = [2, 3, 4, 5, 6, 7, 8];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        for (var i = 0; i < _counts.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: _PeerChip(
              count: _counts[i],
              selected: value == _counts[i],
              enabled: enabled && onChanged != null,
              colorScheme: cs,
              textTheme: tt,
              onTap: enabled && onChanged != null
                  ? () => onChanged!(_counts[i])
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _PeerChip extends StatelessWidget {
  const _PeerChip({
    required this.count,
    required this.selected,
    required this.enabled,
    required this.colorScheme,
    required this.textTheme,
    this.onTap,
  });

  final int count;
  final bool selected;
  final bool enabled;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final fg = selected ? colorScheme.onPrimary : colorScheme.onSurface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              '$count',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: enabled ? fg : fg.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
