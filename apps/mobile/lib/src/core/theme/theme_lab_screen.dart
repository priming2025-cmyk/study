import 'package:flutter/material.dart';

/// 디버그 빌드에서만 라우트로 열리는 컬러·컴포넌트 미리보기.
class ThemeLabScreen extends StatelessWidget {
  const ThemeLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('테마 미리보기'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('ColorScheme', style: text.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Swatch(label: 'primary', color: scheme.primary),
              _Swatch(label: 'secondary', color: scheme.secondary),
              _Swatch(label: 'tertiary', color: scheme.tertiary),
              _Swatch(label: 'surface', color: scheme.surface),
              _Swatch(label: 'containerLow', color: scheme.surfaceContainerLow),
              _Swatch(label: 'outline', color: scheme.outline),
            ],
          ),
          const SizedBox(height: 24),
          Text('타이포', style: text.titleLarge),
          const SizedBox(height: 8),
          Text('headlineMedium', style: text.headlineMedium),
          Text('titleLarge', style: text.titleLarge),
          Text('bodyLarge 본문 톤', style: text.bodyLarge),
          Text(
            'onSurfaceVariant 보조',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Text('컴포넌트', style: text.titleLarge),
          const SizedBox(height: 12),
          FilledButton(onPressed: () {}, child: const Text('Filled')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Card + 테두리', style: text.titleMedium),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('오늘')),
              ButtonSegment(value: 1, label: Text('이번 주')),
            ],
            selected: const {0},
            onSelectionChanged: (_) {},
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
