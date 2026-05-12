import 'package:flutter/material.dart';

import '../data/motivation_repository.dart';
import '../domain/motivation_models.dart';

/// 팀 챌린지: 주간 목표 시간 프리셋으로 빠르게 팀 만들기·참가
class SocialChallengeTab extends StatefulWidget {
  final MotivationRepository repo;
  final TextEditingController squadNameCtrl;
  final TextEditingController joinSquadIdCtrl;
  final VoidCallback onChanged;

  const SocialChallengeTab({
    super.key,
    required this.repo,
    required this.squadNameCtrl,
    required this.joinSquadIdCtrl,
    required this.onChanged,
  });

  @override
  State<SocialChallengeTab> createState() => _SocialChallengeTabState();
}

class _SocialChallengeTabState extends State<SocialChallengeTab> {
  int _presetSeconds = 36000; // 기본 주 10시간

  static const _presets = <({String label, int seconds})>[
    (label: '주 5시간', seconds: 18000),
    (label: '주 10시간', seconds: 36000),
    (label: '주 20시간', seconds: 72000),
    (label: '주 50시간', seconds: 180000),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<List<SquadRow>>(
      future: widget.repo.mySquads(),
      builder: (context, snap) {
        final squads = snap.data ?? const <SquadRow>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('새 챌린지 팀', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(
                      '팀 이름만 적고 목표 시간을 고르면 끝이에요. (월~일 합산 집중 시간)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: widget.squadNameCtrl,
                      decoration: const InputDecoration(
                        labelText: '팀 이름',
                        hintText: '예: 시험대비 반',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('이번 주 팀 목표', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presets.map((p) {
                        final sel = _presetSeconds == p.seconds;
                        return FilterChip(
                          label: Text(p.label),
                          selected: sel,
                          onSelected: (_) => setState(() => _presetSeconds = p.seconds),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () async {
                        final id = await widget.repo.createSquad(
                          name: widget.squadNameCtrl.text,
                          missionTargetSeconds: _presetSeconds,
                        );
                        widget.squadNameCtrl.clear();
                        widget.onChanged();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('챌린지 팀 만들기 완료 · $id')),
                          );
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('팀 만들기'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('팀 참가', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: widget.joinSquadIdCtrl,
                            decoration: const InputDecoration(
                              labelText: '팀 초대 코드(UUID)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () async {
                            final id = widget.joinSquadIdCtrl.text.trim();
                            if (id.isEmpty) return;
                            try {
                              await widget.repo.joinSquadById(id);
                              widget.joinSquadIdCtrl.clear();
                              widget.onChanged();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('참가했어요.')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('참가 실패: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('참가'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('내 챌린지 팀', style: Theme.of(context).textTheme.titleSmall),
            if (squads.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '아직 팀이 없어요. 위에서 만들거나 초대 코드로 들어와요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
            ...squads.map((s) => _ChallengeTeamCard(
                  repo: widget.repo,
                  squad: s,
                  onChanged: widget.onChanged,
                )),
          ],
        );
      },
    );
  }
}

class _ChallengeTeamCard extends StatelessWidget {
  final MotivationRepository repo;
  final SquadRow squad;
  final VoidCallback onChanged;

  const _ChallengeTeamCard({
    required this.repo,
    required this.squad,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: repo.squadWeekProgress(squad.id),
      builder: (context, progSnap) {
        final ratio = progSnap.data == null
            ? 0.0
            : ((progSnap.data!['ratio'] ?? 0) as num).toDouble();
        final hours = (squad.missionTargetSeconds / 3600).toStringAsFixed(
          squad.missionTargetSeconds % 3600 == 0 ? 0 : 1,
        );
        return Card(
          margin: const EdgeInsets.only(top: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(squad.name, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '이번 주 팀 목표 $hours시간',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: ratio.clamp(0.0, 1.0)),
                const SizedBox(height: 6),
                Text('${(ratio * 100).round()}% 달성 · 「미션」 탭에서 진행 안내를 볼 수 있어요'),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      await repo.leaveSquad(squad.id);
                      onChanged();
                    },
                    child: const Text('팀 나가기'),
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
