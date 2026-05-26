import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme_catalog.dart';
import 'app_theme_provider.dart';

/// 집중민감도 설정 시트 하단 — 한 줄 색 테마 스와치.
class AppThemePickerRow extends ConsumerWidget {
  const AppThemePickerRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appThemeIdProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '색 테마',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '탭하면 앱 전체 색이 바뀌어요',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < AppThemeCatalog.all.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _ThemeSwatch(
                  def: AppThemeCatalog.all[i],
                  selected: selected == AppThemeCatalog.all[i].id,
                  onTap: () => ref
                      .read(appThemeIdProvider.notifier)
                      .setTheme(AppThemeCatalog.all[i].id),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.def,
    required this.selected,
    required this.onTap,
  });

  final AppThemeDefinition def;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: def.labelKo,
      child: Semantics(
        label: '${def.labelKo} 테마',
        selected: selected,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 34 : 28,
                height: selected ? 34 : 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: def.swatch,
                  border: Border.all(
                    color: selected ? cs.onSurface : cs.outline.withAlpha(140),
                    width: selected ? 2.5 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: def.swatch.withAlpha(100),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
