import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import 'social_challenge_tab.dart';
import 'social_compete_tab.dart';
import 'social_mission_tab.dart';
import 'social_people_tab.dart';
import 'title_equip_sheet.dart';

/// 사람 · 팀 · 랭킹 · 미션 허브
class SocialHubScreen extends ConsumerStatefulWidget {
  const SocialHubScreen({super.key});

  @override
  ConsumerState<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends ConsumerState<SocialHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  final _friendPeerIdCtrl = TextEditingController();
  final _squadNameCtrl = TextEditingController();
  final _joinSquadIdCtrl = TextEditingController();

  @override
  void dispose() {
    _tabs.dispose();
    _friendPeerIdCtrl.dispose();
    _squadNameCtrl.dispose();
    _joinSquadIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(motivationRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('함께하기'),
        actions: [
          IconButton(
            tooltip: '칭호 착용',
            onPressed: () => showTitleEquipBottomSheet(context, repo),
            icon: const Icon(Icons.military_tech_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: '사람'),
            Tab(text: '팀'),
            Tab(text: '랭킹'),
            Tab(text: '미션'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          SocialPeopleTab(
            repo: repo,
            peerIdCtrl: _friendPeerIdCtrl,
            onChanged: _reload,
          ),
          SocialChallengeTab(
            repo: repo,
            squadNameCtrl: _squadNameCtrl,
            joinSquadIdCtrl: _joinSquadIdCtrl,
            onChanged: _reload,
          ),
          SocialCompeteTab(repo: repo),
          SocialMissionTab(repo: repo),
        ],
      ),
    );
  }
}
