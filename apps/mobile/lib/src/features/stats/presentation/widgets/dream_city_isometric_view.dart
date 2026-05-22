import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/dream_city_state.dart';
import '../../domain/dream_city_tech_tree.dart';
import 'dream_city_painter.dart';

export '../../domain/dream_city_state.dart';
export '../../domain/dream_city_tech_tree.dart';

/// 꿈의 도시 — 아이소메트릭 3D 마을 뷰.
class DreamCityIsometricView extends StatefulWidget {
  final int blockCount;
  final double height;
  final bool animate;

  const DreamCityIsometricView({
    super.key,
    required this.blockCount,
    this.height = 220,
    this.animate = true,
  });

  @override
  State<DreamCityIsometricView> createState() => _DreamCityIsometricViewState();

  /// 하위 호환.
  static List<DreamCityPlacedBuilding> buildingsFromBlocks(int blocks) =>
      DreamCityState.fromBlocks(blocks).placed;
}

class _DreamCityIsometricViewState extends State<DreamCityIsometricView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!widget.animate) return;
      setState(() => _time = elapsed.inMilliseconds / 1000.0);
    });
    if (widget.animate) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = DreamCityState.fromBlocks(widget.blockCount);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: DreamCityPainter(state: state, time: _time),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '집중·계획·친구 블럭으로 꿈의 직업 마을 성장',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                    shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
