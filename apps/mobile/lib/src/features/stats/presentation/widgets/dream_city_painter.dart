import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/dream_city_state.dart';
import '../../domain/dream_city_tech_tree.dart';

/// 아이소메트릭 3D 도시 페인터.
class DreamCityPainter extends CustomPainter {
  final DreamCityState state;
  final double time;

  DreamCityPainter({required this.state, this.time = 0});

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawFarHills(canvas, size);
    _drawWater(canvas, size);

    final cols = state.gridCols;
    final rows = state.gridRows;
    final tw = size.width / (cols + rows + 1.5);
    final th = tw * 0.48;
    final origin = Offset(size.width * 0.5, size.height * 0.78);

    final tiles = <({int x, int y, int z})>[];
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        tiles.add((x: x, y: y, z: x + y));
      }
    }
    tiles.sort((a, b) => a.z.compareTo(b.z));

    for (final t in tiles) {
      _drawIsoTile(
        canvas,
        origin,
        t.x,
        t.y,
        tw,
        th,
        state.isTileUnlocked(t.x, t.y),
      );
    }

    final buildings = List<DreamCityPlacedBuilding>.from(state.placed)
      ..sort((a, b) =>
          (a.def.gridX + a.def.gridY).compareTo(b.def.gridX + b.def.gridY));

    for (final b in buildings) {
      _drawIsoBuilding(canvas, origin, b, tw, th);
    }

    _drawBadge(canvas, size);
  }

  void _drawSky(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          const Color(0xFF87CEEB),
          const Color(0xFFB8E0FF),
          const Color(0xFF4ADE80).withValues(alpha: 0.25),
          const Color(0xFF166534).withValues(alpha: 0.5),
        ],
        [0, 0.35, 0.7, 1],
      );
    canvas.drawRect(rect, paint);

    final sunX = size.width * (0.72 + math.sin(time) * 0.02);
    canvas.drawCircle(
      Offset(sunX, size.height * 0.18),
      22,
      Paint()..color = const Color(0xFFFFE066).withValues(alpha: 0.9),
    );

    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < 3; i++) {
      final cx = size.width * (0.2 + i * 0.28) + math.sin(time + i) * 8;
      final cy = size.height * (0.12 + i * 0.04);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 70, height: 24), cloudPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx + 20, cy + 4), width: 50, height: 18), cloudPaint);
    }
  }

  void _drawFarHills(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.42, size.width * 0.5, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.58, size.width, size.height * 0.48)
      ..lineTo(size.width, size.height * 0.65)
      ..lineTo(0, size.height * 0.65)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF4D7C0F).withValues(alpha: 0.35));
  }

  void _drawWater(Canvas canvas, Size size) {
    final w = Path()
      ..moveTo(0, size.height * 0.88)
      ..lineTo(size.width, size.height * 0.82)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      w,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.82),
          Offset(0, size.height),
          [
            const Color(0xFF38BDF8).withValues(alpha: 0.7),
            const Color(0xFF0369A1),
          ],
        ),
    );
  }

  Offset _iso(Offset origin, int gx, int gy, double tw, double th) {
    final x = (gx - gy) * tw * 0.5;
    final y = (gx + gy) * th * 0.5;
    return origin + Offset(x, -y);
  }

  void _drawIsoTile(
    Canvas canvas,
    Offset origin,
    int gx,
    int gy,
    double tw,
    double th,
    bool unlocked,
  ) {
    final c = _iso(origin, gx, gy, tw, th);
    final h = unlocked ? 6.0 : 2.0;

    final top = Path()
      ..moveTo(c.dx, c.dy - th - h)
      ..lineTo(c.dx + tw * 0.5, c.dy - h)
      ..lineTo(c.dx, c.dy + th - h)
      ..lineTo(c.dx - tw * 0.5, c.dy - h)
      ..close();

    final left = Path()
      ..moveTo(c.dx - tw * 0.5, c.dy - h)
      ..lineTo(c.dx, c.dy + th - h)
      ..lineTo(c.dx, c.dy + th)
      ..lineTo(c.dx - tw * 0.5, c.dy)
      ..close();

    final right = Path()
      ..moveTo(c.dx + tw * 0.5, c.dy - h)
      ..lineTo(c.dx, c.dy + th - h)
      ..lineTo(c.dx, c.dy + th)
      ..lineTo(c.dx + tw * 0.5, c.dy)
      ..close();

    final topColor = unlocked ? const Color(0xFF86EFAC) : const Color(0xFF475569);
    final leftColor = unlocked ? const Color(0xFF22C55E) : const Color(0xFF334155);
    final rightColor = unlocked ? const Color(0xFF16A34A) : const Color(0xFF1E293B);

    canvas.drawPath(left, Paint()..color = leftColor);
    canvas.drawPath(right, Paint()..color = rightColor);
    canvas.drawPath(top, Paint()..color = topColor);

    if (!unlocked) {
      _drawEmoji(canvas, '🔒', c + const Offset(0, -8), 12);
    } else if (state.buildingAt(gx, gy) == null && (gx + gy) % 3 == 0) {
      _drawEmoji(canvas, '🌲', c + Offset(-tw * 0.15, -th * 0.3), 10);
    }
  }

  void _drawIsoBuilding(
    Canvas canvas,
    Offset origin,
    DreamCityPlacedBuilding placed,
    double tw,
    double th,
  ) {
    final def = placed.def;
    final c = _iso(origin, def.gridX, def.gridY, tw, th);
    final bw = tw * 0.42;
    final bh = 14 + def.heightUnits * 14;
    final branchColor = Color(def.branch.colorValue);

    // 그림자
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(0, 4),
        width: bw * 1.4,
        height: th * 0.5,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );

    final base = c + Offset(0, -th * 0.35);
    Offset p(double dx, double dy) => Offset(base.dx + dx, base.dy + dy);

    // 왼쪽 면
    final leftFace = Path()
      ..moveTo(p(-bw * 0.5, 0).dx, p(-bw * 0.5, 0).dy)
      ..lineTo(p(0, bh * 0.35).dx, p(0, bh * 0.35).dy)
      ..lineTo(p(0, bh * 0.35 - bh).dx, p(0, bh * 0.35 - bh).dy)
      ..lineTo(p(-bw * 0.5, -bh).dx, p(-bw * 0.5, -bh).dy)
      ..close();
    canvas.drawPath(
      leftFace,
      Paint()..color = Color.lerp(branchColor, Colors.black, 0.25)!,
    );

    // 오른쪽 면
    final rightFace = Path()
      ..moveTo(p(bw * 0.5, 0).dx, p(bw * 0.5, 0).dy)
      ..lineTo(p(0, bh * 0.35).dx, p(0, bh * 0.35).dy)
      ..lineTo(p(0, bh * 0.35 - bh).dx, p(0, bh * 0.35 - bh).dy)
      ..lineTo(p(bw * 0.5, -bh).dx, p(bw * 0.5, -bh).dy)
      ..close();
    canvas.drawPath(
      rightFace,
      Paint()..color = Color.lerp(branchColor, Colors.black, 0.1)!,
    );

    // 지붕 (다이아)
    final roof = Path()
      ..moveTo(p(0, -bh - 8).dx, p(0, -bh - 8).dy)
      ..lineTo(p(bw * 0.55, -bh * 0.55).dx, p(bw * 0.55, -bh * 0.55).dy)
      ..lineTo(p(0, -bh * 0.2).dx, p(0, -bh * 0.2).dy)
      ..lineTo(p(-bw * 0.55, -bh * 0.55).dx, p(-bw * 0.55, -bh * 0.55).dy)
      ..close();
    canvas.drawPath(
      roof,
      Paint()..color = Color.lerp(branchColor, Colors.white, 0.35)!,
    );

    // 창문
    for (var i = 0; i < def.tier; i++) {
      canvas.drawRect(
        Rect.fromCenter(
          center: p(-bw * 0.22, -bh * 0.35 - i * 10),
          width: 6,
          height: 8,
        ),
        Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.9),
      );
    }

    _drawEmoji(canvas, def.emoji, p(0, -bh - 22), 18 + def.tier.toDouble());
  }

  void _drawEmoji(Canvas canvas, String emoji, Offset at, double size) {
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawBadge(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(text: '🧱 ', style: TextStyle(fontSize: 14)),
          TextSpan(
            text: '${state.blockCount}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(
            text: '  Lv.${state.cityLevel.toStringAsFixed(1)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, 10, tp.width + 20, tp.height + 12),
      const Radius.circular(99),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(r, Paint()..color = Colors.black.withValues(alpha: 0.5));
    tp.paint(canvas, const Offset(20, 16));
  }

  @override
  bool shouldRepaint(DreamCityPainter old) =>
      old.state.blockCount != state.blockCount || old.time != time;
}
