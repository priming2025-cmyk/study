import 'package:flutter/material.dart';

import '../session_controller.dart';

class StartBar extends StatelessWidget {
  final VoidCallback onStart;
  final bool starting;

  const StartBar({super.key, required this.onStart, required this.starting});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: starting ? null : onStart,
        icon: const Icon(Icons.play_arrow),
        label: Text(starting ? '준비중…' : '공부 시작'),
      ),
    );
  }
}

class RunningBar extends StatelessWidget {
  final SessionController c;
  final Future<void> Function() onStop;

  const RunningBar({super.key, required this.c, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final paused = c.state?.paused ?? false;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: c.pauseResume,
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
            label: Text(paused ? '재개' : '일시정지'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => onStop(),
            icon: const Icon(Icons.stop),
            label: const Text('끝내기'),
          ),
        ),
      ],
    );
  }
}

