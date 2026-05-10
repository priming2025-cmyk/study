import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/plan_models.dart';
import 'plan_editor_controller.dart';
import 'widgets/plan_item_card.dart';
import 'widgets/plan_progress_card.dart';
import 'widgets/quick_minutes_chips.dart';
import 'widgets/recent_subjects_row.dart';

class PlanEditorScreen extends ConsumerStatefulWidget {
  const PlanEditorScreen({super.key});

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  late final PlanEditorController _c;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _c = PlanEditorController(repo: ref.read(planRepositoryProvider))
      ..addListener(_onChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _c.bootstrap();
      if (!mounted) return;
      final err = _c.lastBootstrapError;
      if (err != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('불러오기 실패: $err')),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('불러오기 실패: $e')),
        );
      });
    }
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _saveTitle() async {
    try {
      await _c.saveTitle();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('제목 저장 완료')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('제목 저장 실패: $e')));
    }
  }

  Future<void> _addItem({String? subjectOverride}) async {
    try {
      await _c.addItem(subjectOverride: subjectOverride);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('추가 실패: $e')));
    }
  }

  Future<void> _deleteItem(PlanItem item) async {
    try {
      await _c.deleteItem(item);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  Future<void> _toggleDone(PlanItem item, bool done) async {
    try {
      await _c.toggleDone(item, done);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('업데이트 실패: $e')));
    }
  }

  Future<void> _setActualMinutes(PlanItem item, int minutes) async {
    try {
      await _c.setActualMinutes(item, minutes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('실제시간 저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _c.todayPlan;
    final completionRate = plan?.completionRate ?? 0.0;
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 계획표')),
      body: _c.loading && _c.todayPlan == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_c.loading) const LinearProgressIndicator(minHeight: 3),
                if (_c.loading) const SizedBox(height: 8),
                if (_c.showingOfflinePlan)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 20,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '연결이 불안정해요. 마지막으로 저장된 계획을 보여 드려요. 인터넷이 돌아오면 자동으로 맞춰져요.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                PlanProgressCard(
                  completionRate: completionRate,
                  totalActualSeconds: plan?.totalActualSeconds ?? 0,
                  totalTargetSeconds: plan?.totalTargetSeconds ?? 0,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _c.titleController,
                  decoration: InputDecoration(
                    labelText: '계획 제목(선택)',
                    suffixIcon: IconButton(
                      tooltip: '저장',
                      onPressed: _c.savingTitle ? null : _saveTitle,
                      icon: _c.savingTitle
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('빠른 목표시간',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                QuickMinutesChips(
                  selectedMinutes: _c.targetMinutes,
                  onSelected: (m) => setState(() => _c.targetMinutes = m),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _c.subjectController,
                        decoration:
                            const InputDecoration(labelText: '과목/할 일'),
                        onSubmitted: (_) => _addItem(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => _addItem(),
                      child: const Text('추가'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RecentSubjectsRow(
                  subjects: _c.recentSubjects,
                  onTap: (s) => _addItem(subjectOverride: s),
                ),
                if (_c.recentSubjects.isNotEmpty) const SizedBox(height: 12),
                Text('오늘 항목',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                if ((plan?.items ?? const []).isEmpty)
                  Text(
                    '아직 항목이 없어요. 위에서 과목을 추가해보세요.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  )
                else
                  ...plan!.items.map((item) => PlanItemCard(
                        item: item,
                        onDelete: () => _deleteItem(item),
                        onDoneChanged: (v) => _toggleDone(item, v),
                        onActualMinutesChanged: (m) => _setActualMinutes(item, m),
                      )),
              ],
            ),
    );
  }
}

