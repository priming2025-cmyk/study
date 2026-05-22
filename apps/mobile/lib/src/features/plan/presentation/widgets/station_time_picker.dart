import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 지하철 정류장 스타일의 공부 시간 선택기.
/// 30분 단위로 주요 정류장(역)이 있고, 역 사이에서 5분 단위로 세밀 조정 가능.
/// 최소 5분, 최대 240분(4시간).
class StationTimePicker extends StatefulWidget {
  final int initialMinutes;
  final ValueChanged<int> onChanged;

  const StationTimePicker({
    super.key,
    required this.initialMinutes,
    required this.onChanged,
  });

  @override
  State<StationTimePicker> createState() => _StationTimePickerState();
}

class _StationTimePickerState extends State<StationTimePicker>
    with SingleTickerProviderStateMixin {
  late int _minutes;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // 주요 정류장: 0~240분, 30분 단위 (9개)
  static const _stations = [0, 30, 60, 90, 120, 150, 180, 210, 240];
  // 슬라이더 최소/최대 (5분 단위)
  static const _minMinutes = 5;
  static const _maxMinutes = 240;
  static const _step = 5;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes.clamp(_minMinutes, _maxMinutes);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _setMinutes(int value) {
    final snapped = (value / _step).round() * _step;
    final clamped = snapped.clamp(_minMinutes, _maxMinutes);
    if (clamped != _minutes) {
      setState(() => _minutes = clamped);
      widget.onChanged(clamped);
      _pulseController.forward(from: 0);
      HapticFeedback.selectionClick();
    }
  }

  void _snapToStation(int station) {
    if (station == 0) {
      _setMinutes(_minMinutes);
    } else {
      _setMinutes(station);
    }
  }

  String _formatMinutes(int m) {
    if (m < 60) return '$m분';
    final h = m ~/ 60;
    final rem = m % 60;
    if (rem == 0) return '$h시간';
    return '$h시간 $rem분';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ratio = (_minutes - _minMinutes) / (_maxMinutes - _minMinutes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 선택된 시간 대형 표시
        Center(
          child: ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _formatMinutes(_minutes),
                style: tt.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 지하철 트랙 슬라이더
        _SubwayTrack(
          minutes: _minutes,
          ratio: ratio,
          stations: _stations,
          minMinutes: _minMinutes,
          maxMinutes: _maxMinutes,
          onChanged: _setMinutes,
          onStationTap: _snapToStation,
          colorScheme: cs,
        ),
        const SizedBox(height: 8),
        // 정류장 레이블
        _StationLabels(
          stations: _stations,
          currentMinutes: _minutes,
          colorScheme: cs,
          textTheme: tt,
        ),
        const SizedBox(height: 16),
        // ± 버튼 (5분 단위 미세 조정)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AdjustButton(
              icon: Icons.remove,
              label: '-5분',
              onPressed: _minutes > _minMinutes
                  ? () => _setMinutes(_minutes - _step)
                  : null,
              colorScheme: cs,
            ),
            const SizedBox(width: 16),
            _AdjustButton(
              icon: Icons.add,
              label: '+5분',
              onPressed: _minutes < _maxMinutes
                  ? () => _setMinutes(_minutes + _step)
                  : null,
              colorScheme: cs,
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 지하철 트랙 커스텀 위젯
// ─────────────────────────────────────────────
class _SubwayTrack extends StatelessWidget {
  final int minutes;
  final double ratio;
  final List<int> stations;
  final int minMinutes;
  final int maxMinutes;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onStationTap;
  final ColorScheme colorScheme;

  const _SubwayTrack({
    required this.minutes,
    required this.ratio,
    required this.stations,
    required this.minMinutes,
    required this.maxMinutes,
    required this.onChanged,
    required this.onStationTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth - 32;
          return GestureDetector(
            onHorizontalDragUpdate: (details) {
              final localX = details.localPosition.dx - 16;
              final pct = (localX / trackWidth).clamp(0.0, 1.0);
              final raw = minMinutes + pct * (maxMinutes - minMinutes);
              onChanged(raw.round());
            },
            onTapDown: (details) {
              final localX = details.localPosition.dx - 16;
              final pct = (localX / trackWidth).clamp(0.0, 1.0);
              final raw = minMinutes + pct * (maxMinutes - minMinutes);
              onChanged(raw.round());
            },
            child: CustomPaint(
              painter: _SubwayTrackPainter(
                ratio: ratio,
                stations: stations,
                minMinutes: minMinutes,
                maxMinutes: maxMinutes,
                trackColor: colorScheme.primary,
                bgColor: colorScheme.surfaceContainerHigh,
                stationColor: colorScheme.onSurface,
                activeStationColor: colorScheme.primary,
                thumbColor: colorScheme.primary,
                onPrimaryColor: colorScheme.onPrimary,
              ),
              size: Size(constraints.maxWidth, 56),
            ),
          );
        },
      ),
    );
  }
}

class _SubwayTrackPainter extends CustomPainter {
  final double ratio;
  final List<int> stations;
  final int minMinutes;
  final int maxMinutes;
  final Color trackColor;
  final Color bgColor;
  final Color stationColor;
  final Color activeStationColor;
  final Color thumbColor;
  final Color onPrimaryColor;

  _SubwayTrackPainter({
    required this.ratio,
    required this.stations,
    required this.minMinutes,
    required this.maxMinutes,
    required this.trackColor,
    required this.bgColor,
    required this.stationColor,
    required this.activeStationColor,
    required this.thumbColor,
    required this.onPrimaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 16.0;
    final trackWidth = size.width - padding * 2;
    final centerY = size.height / 2;
    const trackHeight = 6.0;

    final bgPaint = Paint()
      ..color = bgColor
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final activePaint = Paint()
      ..color = trackColor
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 배경 트랙
    canvas.drawLine(
      Offset(padding, centerY),
      Offset(padding + trackWidth, centerY),
      bgPaint,
    );

    // 활성 트랙
    final thumbX = padding + ratio * trackWidth;
    canvas.drawLine(
      Offset(padding, centerY),
      Offset(thumbX, centerY),
      activePaint,
    );

    // 정류장 표시
    for (final station in stations) {
      final stRatio = station == 0
          ? 0.0
          : (station - minMinutes) / (maxMinutes - minMinutes);
      final stX = padding + stRatio.clamp(0.0, 1.0) * trackWidth;
      final isActive = ratio >= stRatio - 0.001;
      final isPrimary = station % 60 == 0;

      final stationPaint = Paint()
        ..color = isActive ? activeStationColor : stationColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      final radius = isPrimary ? 7.0 : 5.0;
      canvas.drawCircle(Offset(stX, centerY), radius, stationPaint);

      if (isActive && isPrimary) {
        final innerPaint = Paint()
          ..color = onPrimaryColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(stX, centerY), 3.0, innerPaint);
      }
    }

    // 썸(현재 위치 핸들)
    final thumbPaint = Paint()
      ..color = thumbColor
      ..style = PaintingStyle.fill;
    final thumbShadow = Paint()
      ..color = thumbColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(thumbX, centerY), 14, thumbShadow);
    canvas.drawCircle(Offset(thumbX, centerY), 10, thumbPaint);

    final innerThumbPaint = Paint()
      ..color = onPrimaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(thumbX, centerY), 4, innerThumbPaint);
  }

  @override
  bool shouldRepaint(_SubwayTrackPainter old) =>
      old.ratio != ratio || old.trackColor != trackColor;
}

// ─────────────────────────────────────────────
// 정류장 레이블 행
// ─────────────────────────────────────────────
class _StationLabels extends StatelessWidget {
  final List<int> stations;
  final int currentMinutes;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _StationLabels({
    required this.stations,
    required this.currentMinutes,
    required this.colorScheme,
    required this.textTheme,
  });

  String _label(int m) {
    if (m == 0) return '0';
    if (m < 60) return '$m분';
    return '${m ~/ 60}h';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(stations.length, (i) {
        final station = stations[i];
        final isActive = currentMinutes >= station;
        final isMajor = station % 60 == 0;

        Widget label = Text(
          _label(station),
          style: textTheme.labelSmall?.copyWith(
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontWeight: isActive && isMajor ? FontWeight.w700 : FontWeight.w400,
            fontSize: isMajor ? 11 : 9,
          ),
          textAlign: TextAlign.center,
        );

        // 첫 번째와 마지막은 좌/우 정렬
        if (i == 0) {
          return Expanded(child: Align(alignment: Alignment.centerLeft, child: label));
        }
        if (i == stations.length - 1) {
          return Expanded(child: Align(alignment: Alignment.centerRight, child: label));
        }
        return Expanded(child: Center(child: label));
      }),
    );
  }
}

// ─────────────────────────────────────────────
// ± 조정 버튼
// ─────────────────────────────────────────────
class _AdjustButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;

  const _AdjustButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(56, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Icon(icon, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 슬라이더 값을 가장 가까운 정류장으로 스냅하는 유틸리티.
int snapToNearestStation(double value) {
  const stations = [0, 30, 60, 90, 120, 150, 180, 210, 240];
  return stations.reduce((a, b) =>
      (a - value).abs() < (b - value).abs() ? a : b);
}

double stationProgress(int minutes) =>
    ((minutes - 5) / (240 - 5)).clamp(0.0, 1.0);
