part of 'study_room_member_card.dart';

class _FloatingHeart extends StatefulWidget {
  const _FloatingHeart();

  @override
  State<_FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<_FloatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = Curves.easeOutCubic.transform(_c.value);
              return Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -70 * t),
                  child: Transform.scale(
                    scale: 0.9 + 0.25 * (1 - t),
                    child: const Icon(
                      Icons.favorite,
                      size: 44,
                      color: Color(0xFFFF4D6D),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _JoinElapsedBadge extends StatefulWidget {
  final DateTime joinAt;
  const _JoinElapsedBadge({required this.joinAt});

  @override
  State<_JoinElapsedBadge> createState() => _JoinElapsedBadgeState();
}

class _JoinElapsedBadgeState extends State<_JoinElapsedBadge> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().toUtc().difference(widget.joinAt.toUtc());
    final label = diff.inMinutes < 1
        ? '입장 직후'
        : diff.inHours < 1
            ? '입장 ${diff.inMinutes}분'
            : '입장 ${diff.inHours}시간+';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final ColorScheme cs;
  const _Placeholder({required this.cs});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.person_rounded, size: 48, color: cs.onSurfaceVariant),
        ),
      );
}

class _SnapshotAge extends StatefulWidget {
  final DateTime at;
  const _SnapshotAge({required this.at});

  @override
  State<_SnapshotAge> createState() => _SnapshotAgeState();
}

class _SnapshotAgeState extends State<_SnapshotAge> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(widget.at);
    final label = diff.inSeconds < 90
        ? '방금'
        : diff.inMinutes < 60
            ? '${diff.inMinutes}분 전'
            : '${diff.inHours}시간 전';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }
}
