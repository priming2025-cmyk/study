import 'package:flutter/material.dart';

/// 꿈의 도시 — 스머프빌리지/방치형 느낌의 아이소메트릭 미니 마을.
class DreamCityIsometricView extends StatelessWidget {
  final int blockCount;
  final double height;
  final bool interactive;

  const DreamCityIsometricView({
    super.key,
    required this.blockCount,
    this.height = 200,
    this.interactive = false,
  });

  static List<DreamCityBuilding> buildingsFromBlocks(int blocks) {
    final list = <DreamCityBuilding>[];
    if (blocks >= 5) {
      list.add(const DreamCityBuilding(emoji: '🏠', level: 1, x: 0, y: 0));
    }
    if (blocks >= 20) {
      list.add(const DreamCityBuilding(emoji: '🌳', level: 1, x: 1, y: 0));
    }
    if (blocks >= 40) {
      list.add(const DreamCityBuilding(emoji: '🏫', level: 2, x: 0, y: 1));
    }
    if (blocks >= 70) {
      list.add(const DreamCityBuilding(emoji: '📚', level: 3, x: 1, y: 1));
    }
    if (blocks >= 100) {
      list.add(const DreamCityBuilding(emoji: '☕', level: 3, x: 2, y: 0));
    }
    if (blocks >= 150) {
      list.add(const DreamCityBuilding(emoji: '🏥', level: 4, x: 2, y: 1));
    }
    if (blocks >= 220) {
      list.add(const DreamCityBuilding(emoji: '⚖️', level: 5, x: 0, y: 2));
    }
    if (blocks >= 300) {
      list.add(const DreamCityBuilding(emoji: '🏛️', level: 6, x: 1, y: 2));
    }
    if (blocks >= 500) {
      list.add(const DreamCityBuilding(emoji: '🎓', level: 8, x: 2, y: 2));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final buildings = buildingsFromBlocks(blockCount);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _IsometricCityPainter(
          blockCount: blockCount,
          buildings: buildings,
        ),
        child: interactive
            ? null
            : Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '집중·계획·친구 블럭으로 성장 중',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                ),
              ),
      ),
    );
  }
}

class DreamCityBuilding {
  final String emoji;
  final int level;
  final int x;
  final int y;

  const DreamCityBuilding({
    required this.emoji,
    required this.level,
    required this.x,
    required this.y,
  });
}

class _IsometricCityPainter extends CustomPainter {
  final int blockCount;
  final List<DreamCityBuilding> buildings;

  _IsometricCityPainter({
    required this.blockCount,
    required this.buildings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1E3A5F),
          const Color(0xFF0F172A),
          const Color(0xFF14532D).withValues(alpha: 0.4),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sky);

    // 구름
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.25, size.height * 0.15),
        width: 80,
        height: 28,
      ),
      cloud,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.7, size.height * 0.22),
        width: 60,
        height: 22,
      ),
      cloud,
    );

    const grid = 3;
    final tileW = size.width / (grid + 1.2);
    final tileH = tileW * 0.52;
    final origin = Offset(size.width / 2, size.height * 0.72);

    for (var gy = 0; gy < grid; gy++) {
      for (var gx = 0; gx < grid; gx++) {
        final unlocked = _sectorUnlocked(gx, gy);
        _drawTile(canvas, origin, gx, gy, tileW, tileH, unlocked);
      }
    }

    for (final b in buildings) {
      _drawBuilding(canvas, origin, b, tileW, tileH);
    }

    // 블럭 카운터 배지
    final badge = TextPainter(
      text: TextSpan(
        text: '🧱 $blockCount',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 12, badge.width + 16, badge.height + 10),
      const Radius.circular(99),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    badge.paint(canvas, const Offset(20, 17));
  }

  bool _sectorUnlocked(int x, int y) {
    final idx = y * 3 + x;
    if (blockCount >= 200) return true;
    if (blockCount >= 120) return idx < 8;
    if (blockCount >= 60) return idx < 6;
    if (blockCount >= 30) return idx < 4;
    if (blockCount >= 10) return idx < 2;
    return idx == 0;
  }

  Offset _isoPoint(Offset origin, int gx, int gy, double tw, double th) {
    final x = (gx - gy) * tw * 0.5;
    final y = (gx + gy) * th * 0.5;
    return origin + Offset(x, -y);
  }

  void _drawTile(
    Canvas canvas,
    Offset origin,
    int gx,
    int gy,
    double tw,
    double th,
    bool unlocked,
  ) {
    final c = _isoPoint(origin, gx, gy, tw, th);
    final path = Path()
      ..moveTo(c.dx, c.dy - th)
      ..lineTo(c.dx + tw * 0.5, c.dy)
      ..lineTo(c.dx, c.dy + th)
      ..lineTo(c.dx - tw * 0.5, c.dy)
      ..close();

    final top = Paint()
      ..color = unlocked
          ? const Color(0xFF4ADE80).withValues(alpha: 0.35)
          : const Color(0xFF334155).withValues(alpha: 0.5);
    final left = Paint()
      ..color = unlocked
          ? const Color(0xFF16A34A).withValues(alpha: 0.5)
          : const Color(0xFF1E293B);
    final right = Paint()
      ..color = unlocked
          ? const Color(0xFF15803D).withValues(alpha: 0.6)
          : const Color(0xFF0F172A);

    canvas.drawPath(path, top);
    canvas.drawLine(
      c + Offset(-tw * 0.5, 0),
      c + Offset(0, th),
      Paint()
        ..color = left.color
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      c + Offset(tw * 0.5, 0),
      c + Offset(0, th),
      Paint()
        ..color = right.color
        ..strokeWidth = 2,
    );

    if (!unlocked) {
      final lock = TextPainter(
        text: const TextSpan(text: '🔒', style: TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      lock.paint(canvas, c - Offset(lock.width / 2, lock.height / 2 + 4));
    }
  }

  void _drawBuilding(
    Canvas canvas,
    Offset origin,
    DreamCityBuilding b,
    double tw,
    double th,
  ) {
    final base = _isoPoint(origin, b.x, b.y, tw, th);
    final h = 18 + b.level * 4.0;

    // 건물 본체 (간단한 3D 박스)
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: base + Offset(0, -h - th * 0.3),
        width: tw * 0.55,
        height: h,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.amber, Colors.orange, b.level / 8)!,
            const Color(0xFF78350F),
          ],
        ).createShader(body.outerRect),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: b.emoji,
        style: TextStyle(fontSize: 16 + b.level.toDouble()),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      base + Offset(-tp.width / 2, -h - th * 0.5 - tp.height),
    );
  }

  @override
  bool shouldRepaint(_IsometricCityPainter old) =>
      old.blockCount != blockCount || old.buildings != buildings;
}
