import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/daily_focus_stat.dart';

String formatFocusDuration(int seconds) {
  if (seconds <= 0) return '0분';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '$h시간 $m분';
  return '$m분';
}

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  late Future<List<DailyFocusStat>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DailyFocusStat>> _load() {
    return ref.read(sessionRepositoryProvider).fetchDailyFocusLastDays(7);
  }

  Future<void> _onRefresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('집중 기록'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<DailyFocusStat>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '불러오지 못했어요.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          final stats = snapshot.data ?? const <DailyFocusStat>[];
          final maxSec = stats.fold<int>(
            1,
            (m, e) => e.focusedSeconds > m ? e.focusedSeconds : m,
          );
          final total = stats.fold<int>(0, (a, e) => a + e.focusedSeconds);
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '최근 7일',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0
                      ? '세션을 끝내면 여기에 쌓여요. 하루 한 번만 열어도 충분해요.'
                      : '합계 ${formatFocusDuration(total)} · 그래프는 가장 긴 날 기준이에요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                ...stats.map((e) => _DayRow(stat: e, maxSeconds: maxSec)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.stat, required this.maxSeconds});

  final DailyFocusStat stat;
  final int maxSeconds;

  static String _weekdayShort(DateTime d) {
    return switch (d.weekday) {
      DateTime.monday => '월',
      DateTime.tuesday => '화',
      DateTime.wednesday => '수',
      DateTime.thursday => '목',
      DateTime.friday => '금',
      DateTime.saturday => '토',
      _ => '일',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = maxSeconds <= 0 ? 0.0 : stat.focusedSeconds / maxSeconds;
    final label =
        '${stat.dayLocal.month}/${stat.dayLocal.day} (${_weekdayShort(stat.dayLocal)})';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text(
              formatFocusDuration(stat.focusedSeconds),
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
