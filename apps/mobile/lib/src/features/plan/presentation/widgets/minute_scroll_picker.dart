import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 5분 단위 스크롤 선택 (시작 시각·소요 시간).
class MinuteScrollPicker extends StatefulWidget {
  final int valueMinutes;
  final int minMinutes;
  final int maxMinutes;
  final int stepMinutes;
  final ValueChanged<int> onChanged;
  final String Function(int minutes)? labelBuilder;
  final bool showAmPmToggle;
  final bool isDuration;

  const MinuteScrollPicker({
    super.key,
    required this.valueMinutes,
    required this.onChanged,
    this.minMinutes = 0,
    this.maxMinutes = 24 * 60 - 1,
    this.stepMinutes = 5,
    this.labelBuilder,
    this.showAmPmToggle = false,
    this.isDuration = false,
  });

  @override
  State<MinuteScrollPicker> createState() => _MinuteScrollPickerState();
}

class _MinuteScrollPickerState extends State<MinuteScrollPicker> {
  late FixedExtentScrollController _ctrl;
  late List<int> _values;
  bool _isPm = false;

  @override
  void initState() {
    super.initState();
    _values = _buildValues();
    final idx = _values.indexOf(_clamp(widget.valueMinutes));
    _ctrl = FixedExtentScrollController(initialItem: idx < 0 ? 0 : idx);
    if (widget.showAmPmToggle && !widget.isDuration) {
      final h = widget.valueMinutes ~/ 60;
      _isPm = h >= 12;
    }
  }

  List<int> _buildValues() {
    final list = <int>[];
    for (var m = widget.minMinutes; m <= widget.maxMinutes; m += widget.stepMinutes) {
      list.add(m);
    }
    return list;
  }

  int _clamp(int m) {
    if (m < widget.minMinutes) return widget.minMinutes;
    if (m > widget.maxMinutes) return widget.maxMinutes;
    return ((m / widget.stepMinutes).round() * widget.stepMinutes);
  }

  String _label(int minutes) {
    if (widget.labelBuilder != null) return widget.labelBuilder!(minutes);
    if (widget.isDuration) {
      final h = minutes ~/ 60;
      final mm = minutes % 60;
      if (h > 0 && mm > 0) return '$h시간 $mm분';
      if (h > 0) return '$h시간';
      return '$mm분';
    }
    final h24 = minutes ~/ 60;
    final mm = minutes % 60;
    final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
    final ap = h24 < 12 ? '오전' : '오후';
    return '$ap $h12:${mm.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        if (widget.showAmPmToggle && !widget.isDuration)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('오전')),
                ButtonSegment(value: true, label: Text('오후')),
              ],
              selected: {_isPm},
              onSelectionChanged: (s) {
                setState(() => _isPm = s.first);
                HapticFeedback.selectionClick();
              },
            ),
          ),
        SizedBox(
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: _ctrl,
                itemExtent: 44,
                perspective: 0.003,
                diameterRatio: 1.4,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  HapticFeedback.selectionClick();
                  widget.onChanged(_values[i]);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _values.length,
                  builder: (context, i) {
                    final sel = _ctrl.hasClients && _ctrl.selectedItem == i;
                    return Center(
                      child: Text(
                        _label(_values[i]),
                        style: (sel ? tt.titleMedium : tt.bodyMedium)?.copyWith(
                          fontWeight: sel ? FontWeight.w800 : FontWeight.w400,
                          color: sel ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              onPressed: () {
                if (!_ctrl.hasClients) return;
                final next = (_ctrl.selectedItem - 1).clamp(0, _values.length - 1);
                _ctrl.animateToItem(next,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut);
              },
            ),
            Text('위·아래로 5분씩', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: () {
                if (!_ctrl.hasClients) return;
                final next = (_ctrl.selectedItem + 1).clamp(0, _values.length - 1);
                _ctrl.animateToItem(next,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut);
              },
            ),
          ],
        ),
      ],
    );
  }
}
