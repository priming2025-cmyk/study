import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 스크롤 휠 시간 선택. [compact] 시 5·10·15분 칩이 휠 위, 세로 4줄 높이.
class MinuteScrollPicker extends StatefulWidget {
  final int valueMinutes;
  final int minMinutes;
  final int maxMinutes;
  final int initialStepMinutes;
  final ValueChanged<int> onChanged;
  final String Function(int minutes)? labelBuilder;
  final bool showAmPmToggle;
  final bool isDuration;

  /// 시간계획 탭용: 세로·가로 최소화 (휠 약 4줄 높이).
  final bool compact;

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
    this.compact = false,
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

  // 컴팩트: 한 줄 높이 28px × 4줄 = 휠 영역 전체 높이
  static const _lineH = 28.0;
  static const _compactLines = 4;
  static const _compactWheelH = _lineH * _compactLines;
  static const _compactWheelW = 128.0;
  static const _compactArrowW = 32.0;

  // 기본(시간 설정 시트 등)
  static const _wheelHeight = 168.0;
  static const _wheelWidth = 200.0;
  static const _arrowColWidth = 44.0;
  static const _stepColWidth = 52.0;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStepMinutes;
    _values = _buildValues();
    _ctrl = FixedExtentScrollController(
      initialItem: _indexFor(_clamp(widget.valueMinutes)),
    );
    if (widget.showAmPmToggle && !widget.isDuration) {
      _isPm = widget.valueMinutes ~/ 60 >= 12;
    }
  }

  @override
  void didUpdateWidget(MinuteScrollPicker old) {
    super.didUpdateWidget(old);
    if (old.valueMinutes != widget.valueMinutes && _ctrl.hasClients) {
      final idx = _indexFor(_clamp(widget.valueMinutes));
      if (idx != _ctrl.selectedItem) _ctrl.jumpToItem(idx);
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
    return ((m / _step).round() * _step)
        .clamp(widget.minMinutes, widget.maxMinutes);
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
      _ctrl.dispose();
      _ctrl = FixedExtentScrollController(initialItem: _indexFor(clamped));
    });
    HapticFeedback.selectionClick();
  }

  /// 13:00 → 오후 1시, 01:00 → 오전 1시
  static String _koreanClockLabel(int minutes) {
    final h24 = minutes ~/ 60;
    final mm = minutes % 60;
    final ap = h24 < 12 ? '오전' : '오후';
    var h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    if (mm == 0) return '$ap $h12시';
    return '$ap $h12시 $mm분';
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
    if (widget.showAmPmToggle) {
      final h24 = minutes ~/ 60;
      final mm = minutes % 60;
      final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
      final ap = h24 < 12 ? '오전' : '오후';
      return '$ap $h12:${mm.toString().padLeft(2, '0')}';
    }
    return _koreanClockLabel(minutes);
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

  Widget _stepChipsRow(ColorScheme cs, TextTheme tt, {bool dense = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: _steps.map((s) {
        final sel = _step == s;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: dense ? 3 : 4),
          child: Material(
            color: sel ? cs.surfaceContainerHigh : cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _setStep(s),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 10 : 8,
                  vertical: dense ? 4 : 5,
                ),
                child: Text(
                  '$s분',
                  style: tt.labelSmall?.copyWith(
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    fontSize: dense ? 12 : null,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _wheelStack(
    ColorScheme cs,
    TextTheme tt, {
    required double height,
    required double width,
    required double itemExtent,
    required double highlightH,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: highlightH,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: _ctrl,
            itemExtent: itemExtent,
            perspective: 0.004,
            diameterRatio: 1.15,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (sel ? tt.titleSmall : tt.bodySmall)?.copyWith(
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w400,
                      fontSize: widget.compact ? 13 : null,
                      color: sel ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrowBtn({
    required IconData icon,
    required VoidCallback onPressed,
    required ColorScheme cs,
    required double size,
  }) {
    return SizedBox(
      width: _compactArrowW,
      height: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 22,
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        onPressed: onPressed,
        icon: Icon(icon, color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _buildCompact(ColorScheme cs, TextTheme tt) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepChipsRow(cs, tt, dense: true),
        const SizedBox(height: 4),
        SizedBox(
          width: _compactWheelW + _compactArrowW * 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _arrowBtn(
                icon: Icons.keyboard_arrow_up_rounded,
                onPressed: () => _nudge(-1),
                cs: cs,
                size: _lineH,
              ),
              SizedBox(
                height: _compactWheelH,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: _compactArrowW),
                    _wheelStack(
                      cs,
                      tt,
                      height: _compactWheelH,
                      width: _compactWheelW,
                      itemExtent: _lineH,
                      highlightH: _lineH,
                    ),
                    SizedBox(width: _compactArrowW),
                  ],
                ),
              ),
              _arrowBtn(
                icon: Icons.keyboard_arrow_down_rounded,
                onPressed: () => _nudge(1),
                cs: cs,
                size: _lineH,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClassic(ColorScheme cs, TextTheme tt) {
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
        Center(
          child: SizedBox(
            height: _wheelHeight,
            width: _stepColWidth + _arrowColWidth + _wheelWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _stepColWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _steps.map((s) {
                      final sel = _step == s;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Material(
                          color: sel
                              ? cs.surfaceContainerHigh
                              : cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _setStep(s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              child: Text(
                                '$s분',
                                style: tt.labelSmall?.copyWith(
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(
                  width: _arrowColWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        iconSize: 32,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: _arrowColWidth,
                          minHeight: _arrowColWidth,
                        ),
                        onPressed: () => _nudge(-1),
                        icon: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      IconButton(
                        iconSize: 32,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: _arrowColWidth,
                          minHeight: _arrowColWidth,
                        ),
                        onPressed: () => _nudge(1),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _wheelStack(
                  cs,
                  tt,
                  height: _wheelHeight,
                  width: _wheelWidth,
                  itemExtent: 44,
                  highlightH: 44,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (widget.compact) {
      return _buildCompact(cs, tt);
    }
    return _buildClassic(cs, tt);
  }
}
