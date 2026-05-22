import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 스크롤 + 위·아래 버튼 시간 선택. 간격(5·10·15분) 변경 가능.
class MinuteScrollPicker extends StatefulWidget {
  final int valueMinutes;
  final int minMinutes;
  final int maxMinutes;
  final int initialStepMinutes;
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
    this.initialStepMinutes = 5,
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
  late int _step;
  bool _isPm = false;

  static const _steps = [5, 10, 15];

  @override
  void initState() {
    super.initState();
    _step = widget.initialStepMinutes;
    _values = _buildValues();
    final idx = _indexFor(_clamp(widget.valueMinutes));
    _ctrl = FixedExtentScrollController(initialItem: idx);
    if (widget.showAmPmToggle && !widget.isDuration) {
      _isPm = widget.valueMinutes ~/ 60 >= 12;
    }
  }

  @override
  void didUpdateWidget(MinuteScrollPicker old) {
    super.didUpdateWidget(old);
    if (old.valueMinutes != widget.valueMinutes && _ctrl.hasClients) {
      final idx = _indexFor(_clamp(widget.valueMinutes));
      if (idx != _ctrl.selectedItem) {
        _ctrl.jumpToItem(idx);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<int> _buildValues() {
    final list = <int>[];
    for (var m = widget.minMinutes; m <= widget.maxMinutes; m += _step) {
      list.add(m);
    }
    return list;
  }

  int _clamp(int m) {
    if (m < widget.minMinutes) return widget.minMinutes;
    if (m > widget.maxMinutes) return widget.maxMinutes;
    final rounded = ((m / _step).round() * _step);
    return rounded.clamp(widget.minMinutes, widget.maxMinutes);
  }

  int _indexFor(int m) {
    final idx = _values.indexOf(m);
    if (idx >= 0) return idx;
    var best = 0;
    var bestDiff = 1 << 30;
    for (var i = 0; i < _values.length; i++) {
      final d = (_values[i] - m).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = i;
      }
    }
    return best;
  }

  void _setStep(int step) {
    if (_step == step) return;
    setState(() {
      _step = step;
      _values = _buildValues();
      final clamped = _clamp(widget.valueMinutes);
      widget.onChanged(clamped);
      final idx = _indexFor(clamped);
      _ctrl.dispose();
      _ctrl = FixedExtentScrollController(initialItem: idx);
    });
    HapticFeedback.selectionClick();
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

  void _nudge(int delta) {
    if (!_ctrl.hasClients) return;
    final next = (_ctrl.selectedItem + delta).clamp(0, _values.length - 1);
    _ctrl.animateToItem(
      next,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final current = _ctrl.hasClients
        ? _values[_ctrl.selectedItem.clamp(0, _values.length - 1)]
        : _clamp(widget.valueMinutes);

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
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _steps.map((s) {
                  final sel = _step == s;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Material(
                      color: sel
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _setStep(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Text(
                            '${s}분',
                            style: tt.labelSmall?.copyWith(
                              fontWeight:
                                  sel ? FontWeight.w800 : FontWeight.w500,
                              color: sel ? cs.primary : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 4),
              IconButton(
                iconSize: 36,
                tooltip: '이전',
                onPressed: () => _nudge(-1),
                icon: Icon(Icons.keyboard_arrow_up_rounded, color: cs.primary),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    Text(
                      _label(current),
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        fontSize: 28,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    IgnorePointer(
                      child: ListWheelScrollView.useDelegate(
                        controller: _ctrl,
                        itemExtent: 56,
                        perspective: 0.002,
                        diameterRatio: 1.2,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (i) {
                          HapticFeedback.selectionClick();
                          widget.onChanged(_values[i]);
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: _values.length,
                          builder: (context, i) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                iconSize: 36,
                tooltip: '다음',
                onPressed: () => _nudge(1),
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: cs.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
