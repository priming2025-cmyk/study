import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../domain/motivation_models.dart';

class GachaShopScreen extends ConsumerStatefulWidget {
  const GachaShopScreen({super.key});

  @override
  ConsumerState<GachaShopScreen> createState() => _GachaShopScreenState();
}

class _GachaShopScreenState extends ConsumerState<GachaShopScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(motivationRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('뽑기 상점')),
      body: FutureBuilder<List<CosmeticItemRow>>(
        future: repo.myCosmetics(),
        builder: (context, snap) {
          final items = snap.data ?? const <CosmeticItemRow>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('코인 뽑기', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        '50코인으로 테두리·이모티콘을 무작위로 받아요.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                try {
                                  final r = await repo.pullGacha(cost: 50);
                                  if (!context.mounted) return;
                                  if (r.containsKey('error')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${r['error']}')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('획득: ${r['name_ko'] ?? r['key']}'),
                                      ),
                                    );
                                  }
                                  setState(() {});
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('뽑기 실패: $e')),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        child: Text(_busy ? '처리 중…' : '50코인 뽑기'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('내 치장', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...items.map((c) {
                if (c.kind != 'border') {
                  return ListTile(title: Text(c.nameKo), subtitle: Text(c.rarity));
                }
                return ListTile(
                  title: Text(c.nameKo),
                  subtitle: Text('${c.kind} · ${c.rarity}'),
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        await repo.equipBorder(c.key);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('테두리를 적용했어요.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('적용 실패: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('착용'),
                  ),
                );
              }),
              if (items.isEmpty)
                Text(
                  '아직 획득한 치장이 없어요. 뽑기를 눌러 보세요.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          );
        },
      ),
    );
  }
}
