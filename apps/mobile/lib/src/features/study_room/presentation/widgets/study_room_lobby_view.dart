import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'friend_status_section.dart';
import 'study_group_browser_sheet.dart';

/// 셋터디 로비 뷰 — 친구 상태 + 방 만들기/참여 + 그룹 탐색.
class StudyRoomLobbyView extends ConsumerStatefulWidget {
  final TextEditingController roomNameCtrl;
  final TextEditingController roomIdCtrl;
  final bool joining;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final String? recentRoomId;
  final VoidCallback? onQuickJoinRecent;
  final String? userDisplayName;

  const StudyRoomLobbyView({
    super.key,
    required this.roomNameCtrl,
    required this.roomIdCtrl,
    required this.joining,
    required this.onCreate,
    required this.onJoin,
    this.recentRoomId,
    this.onQuickJoinRecent,
    this.userDisplayName,
  });

  @override
  ConsumerState<StudyRoomLobbyView> createState() =>
      _StudyRoomLobbyViewState();
}

class _StudyRoomLobbyViewState extends ConsumerState<StudyRoomLobbyView> {
  bool _showRoomNameField = false;

  @override
  void initState() {
    super.initState();
    // 방 이름 자동 생성
    final name = widget.userDisplayName ?? '나';
    widget.roomNameCtrl.text = '$name의 공부방';
  }

  void _openGroupBrowser() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudyGroupBrowserSheet(
        onApply: (group) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('「${group.name}」에 가입 신청했어요! 수락되면 알림을 드려요.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    String shortId(String id) =>
        id.length <= 8 ? id : '${id.substring(0, 8)}…';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // 친구 실시간 상태 섹션
        FriendStatusSection(
          onInvite: (friend) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${friend.displayName}에게 초대를 보냈어요!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          onCheer: (friend) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${friend.displayName}에게 응원을 보냈어요 👊'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),

        // 빠른 재참여
        if (widget.recentRoomId != null &&
            widget.onQuickJoinRecent != null) ...[
          _SectionCard(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.history_rounded,
                    color: cs.onSecondaryContainer),
              ),
              title: const Text('최근 셋으로 빠른 입장'),
              subtitle: Text('셋 ID: ${shortId(widget.recentRoomId!)}'),
              trailing: widget.joining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              onTap: widget.joining ? null : widget.onQuickJoinRecent,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 셋 만들기
        Row(
          children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text('새 셋 만들기',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 방 이름 표시 (탭하면 편집 가능)
              GestureDetector(
                onTap: () =>
                    setState(() => _showRoomNameField = !_showRoomNameField),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.roomNameCtrl.text.isEmpty
                                ? '공부방 이름 자동 생성'
                                : widget.roomNameCtrl.text,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '방 이름을 바꾸려면 탭하세요',
                            style: tt.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _showRoomNameField
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.edit_outlined,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              if (_showRoomNameField) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: widget.roomNameCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '방 이름 입력',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  autofocus: true,
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.joining
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          setState(() => _showRoomNameField = false);
                          widget.onCreate();
                        },
                  icon: widget.joining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_rounded),
                  label: Text(widget.joining ? '생성 중…' : '셋 만들기'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 셋 ID로 참여
        Row(
          children: [
            Icon(Icons.login_rounded, size: 20, color: cs.secondary),
            const SizedBox(width: 8),
            Text('ID로 참여하기',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        _SectionCard(
          child: Column(
            children: [
              TextField(
                controller: widget.roomIdCtrl,
                decoration: InputDecoration(
                  hintText: '셋 ID 붙여넣기',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  prefixIcon: const Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.joining ? null : widget.onJoin,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('참여하기'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 그룹 찾기
        const Divider(),
        const SizedBox(height: 16),
        _GroupFindBanner(
          onTap: _openGroupBrowser,
          cs: cs,
          tt: tt,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 섹션 카드 래퍼
// ─────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
// 그룹 찾기 배너
// ─────────────────────────────────────────────
class _GroupFindBanner extends StatelessWidget {
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  const _GroupFindBanner({
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer,
              cs.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '스터디 그룹 찾기 🔍',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '중학교 · 고등학교 · 대학교\n집중점수 높은 그룹과 함께 공부해요',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_forward_rounded,
                  color: cs.onPrimary, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
