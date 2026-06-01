import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/study_room_focus_timeline.dart';

/// 프로필(휴식·캡쳐 OFF) 위 집중도 흐름 — 영역 차트 + 이동 평균.
class StudyRoomFocusTrendOverlay extends StatelessWidget {
  final List<int> scores;
  final int? headlineScore;
  final String? subtitle;

  const StudyRoomFocusTrendOverlay({
    super.key,
    required this.scores,
    this.headlineScore,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    var chartScores = StudyRoomFocusTimeline.downsampleScores(scores);
    if (chartScores.length == 1) {
      final v = chartScores.first;
      chartScores = [v, v, v];
    } else if (chartScores.length == 2) {
      chartScores = [chartScores.first, chartScores.last, chartScores.last];
    }
    final avg = headlineScore ?? StudyRoomFocusTimeline.averageOf(chartScores);
    final hasChart = chartScores.length >= StudyRoomFocusTimeline.minPointsForChart;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0.72),
            Colors.black.withValues(alpha: 0.88),
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            if (hasChart)
              Expanded(
                flex: 3,
                child: CustomPaint(
                  painter: _FocusAreaChartPainter(
                    scores: chartScores,
                    lineColor: _scoreAccent(avg),
                  ),
                  child: const SizedBox.expand(),
                ),
              )
            else
              const Spacer(flex: 2),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$avg',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Text(
                    '집중도',
                    style: TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              '집중 흐름',
              style: TextStyle(
                color: Color(0x80FFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _scoreAccent(int score) {
    if (score >= 75) return const Color(0xFF4ADE80);
    if (score >= 50) return const Color(0xFFFBBF24);
    return const Color(0xFFF87171);
  }
}

class _FocusAreaChartPainter extends CustomPainter {
  final List<int> scores;
  final Color lineColor;

  _FocusAreaChartPainter({
    required this.scores,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2 || size.width < 8 || size.height < 8) return;

    final w = size.width;
    final h = size.height;
    const padL = 0.0;
    const padR = 4.0;
    const padT = 6.0;
    const padB = 4.0;
    final chartW = w - padL - padR;
    final chartH = h - padT - padB;

    for (final level in [25.0, 50.0, 75.0]) {
      final y = padT + chartH * (1 - level / 100);
      canvas.drawLine(
        Offset(padL, y),
        Offset(padL + chartW, y),
        Paint()
          ..color = const Color(0x18FFFFFF)
          ..strokeWidth = 1,
      );
    }

    final points = <Offset>[];
    for (var i = 0; i < scores.length; i++) {
      final t = scores.length == 1 ? 0.0 : i / (scores.length - 1);
      final x = padL + chartW * t;
      final y = padT + chartH * (1 - scores[i].clamp(0, 100) / 100);
      points.add(Offset(x, y));
    }

    final smooth = _smoothPath(points);
    if (smooth == null) return;

    final fillPath = Path.from(smooth)
      ..lineTo(padL + chartW, padT + chartH)
      ..lineTo(padL, padT + chartH)
      ..close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, padT),
        Offset(0, padT + chartH),
        [
          lineColor.withValues(alpha: 0.45),
          lineColor.withValues(alpha: 0.02),
        ],
      );
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(smooth, linePaint);

    final last = points.last;
    canvas.drawCircle(
      last,
      4.5,
      Paint()..color = lineColor,
    );
    canvas.drawCircle(
      last,
      7.5,
      Paint()
        ..color = lineColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  Path? _smoothPath(List<Offset> points) {
    if (points.length < 2) return null;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _FocusAreaChartPainter oldDelegate) =>
      oldDelegate.scores != scores || oldDelegate.lineColor != lineColor;
}
