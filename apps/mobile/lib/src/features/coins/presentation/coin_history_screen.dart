import 'package:flutter/material.dart';

import '../../session/data/session_repository.dart';
import '../../session/domain/wallet_balances.dart';
import '../data/coin_repository.dart';
import '../domain/coin_event_entry.dart';

String _formatCoinTime(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class CoinHistoryScreen extends StatelessWidget {
  const CoinHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보상 내역'),
      ),
      body: FutureBuilder<List<CoinEventEntry>>(
        future: const CoinRepository().fetchRecentEvents(limit: 150),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('불러오기 실패: ${snapshot.error}'));
          }
          final all = snapshot.data ?? const [];

          final startOfToday = DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          );
          final today = all.where((e) =>
              !e.createdAt.isBefore(startOfToday)).toList();
          today.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final sessionsMap = <String, List<CoinEventEntry>>{};
          for (final e in all) {
            final sid = e.sessionId;
            if (sid == null) continue;
            sessionsMap.putIfAbsent(sid, () => []).add(e);
          }
          for (final list in sessionsMap.values) {
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }

          final todayBlocks = today
              .where((e) => e.asset == 'block')
              .fold<int>(0, (s, e) => s + e.coins);
          final todayRedeem = today
              .where((e) => e.asset == 'redeem_coin')
              .fold<int>(0, (s, e) => s + e.coins);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BalanceHeader(
                future: const SessionRepository().fetchWalletBalances(),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘 변동',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '블럭 합계 ${todayBlocks >= 0 ? '+' : ''}$todayBlocks · '
                        '코인 합계 ${todayRedeem >= 0 ? '+' : ''}$todayRedeem (${today.length}건)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (today.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '아직 오늘 기록된 내역이 없어요.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        )
                      else
                        ...today.map((e) => _EventTile(e)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '공부별',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (sessionsMap.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '공부로 번 블럭만 묶입니다. 보너스·교환 코인은 전체 목록에서 확인해요.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                ...sessionsMap.entries.map((en) {
                  final sum = en.value.fold<int>(0, (s, e) => s + e.coins);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      title: Text(
                        '공부 ${en.key.length > 8 ? '${en.key.substring(0, 8)}…' : en.key}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        '${sum >= 0 ? '+' : ''}$sum ${CoinRepository.assetUnitKo('block')}',
                      ),
                      children: en.value
                          .map((e) => ListTile(
                                dense: true,
                                title: Text(CoinRepository.kindLabelKo(e.kind)),
                                trailing: Text(
                                  CoinRepository.formatSignedAmount(e),
                                ),
                                subtitle: Text(_formatCoinTime(e.createdAt)),
                              ))
                          .toList(),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              Text(
                '전체 최근',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...all.map((e) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(CoinRepository.kindLabelKo(e.kind)),
                      subtitle: Text(_formatCoinTime(e.createdAt)),
                      trailing: Text(
                        CoinRepository.formatSignedAmount(e),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  final Future<WalletBalances> future;

  const _BalanceHeader({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WalletBalances>(
      future: future,
      builder: (context, snap) {
        final w = snap.data ?? WalletBalances.zero;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.toll,
                    size: 40, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('보유 블럭', style: Theme.of(context).textTheme.labelLarge),
                      Text(
                        '${w.blocks}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text('교환 코인', style: Theme.of(context).textTheme.labelLarge),
                      Text(
                        '${w.redeemCoins}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  final CoinEventEntry entry;

  const _EventTile(this.entry);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(CoinRepository.kindLabelKo(entry.kind)),
      subtitle: Text(_formatCoinTime(entry.createdAt)),
      trailing: Text(
        CoinRepository.formatSignedAmount(entry),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
