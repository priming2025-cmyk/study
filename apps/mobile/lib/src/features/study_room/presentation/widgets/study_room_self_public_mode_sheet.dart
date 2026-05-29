import 'package:flutter/material.dart';

Future<void> showStudyRoomSelfPublicModeSheet(
  BuildContext context, {
  required String current,
  required Future<void> Function(String mode) onSelect,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _Body(
      current: current,
      onSelect: (m) async {
        await onSelect(m);
        if (ctx.mounted) Navigator.of(ctx).pop();
      },
    ),
  );
}

class _Body extends StatelessWidget {
  final String current;
  final Future<void> Function(String mode) onSelect;

  const _Body({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('내 공개 모드', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _ModeTile(
              selected: current == 'capture',
              title: '캡쳐',
              subtitle: '1분마다 캡쳐 공유',
              icon: Icons.camera_alt_outlined,
              onTap: () => onSelect('capture'),
            ),
            _ModeTile(
              selected: current == 'video',
              title: '2초 영상',
              subtitle: '시작 시 2초 영상 · 이후 10분마다',
              icon: Icons.videocam_outlined,
              onTap: () => onSelect('video'),
            ),
            _ModeTile(
              selected: current == 'rest',
              title: '휴식 중',
              subtitle: '프로필로 대체',
              icon: Icons.coffee_outlined,
              onTap: () => onSelect('rest'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: selected ? cs.primaryContainer.withValues(alpha: 0.6) : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

