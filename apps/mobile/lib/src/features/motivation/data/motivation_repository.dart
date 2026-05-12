import '../../../core/supabase/supabase_client.dart';
import '../domain/motivation_models.dart';

class MotivationRepository {
  const MotivationRepository();

  Future<ProfileRpgSummary?> fetchMyProfileRpg() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await supabase
        .from('profiles')
        .select(
          'xp_total, level, streak_current, streak_best, equipped_title_id, equipped_border_key',
        )
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;

    String? titleKo;
    final tid = row['equipped_title_id'] as String?;
    if (tid != null) {
      final t = await supabase.from('titles').select('name_ko').eq('id', tid).maybeSingle();
      titleKo = t?['name_ko'] as String?;
    }
    return ProfileRpgSummary.fromProfileRow(row, titleKo: titleKo);
  }

  Future<List<FriendRow>> listFriends() async {
    final rows = await supabase.rpc('list_friends');
    if (rows is! List) return const [];
    return rows
        .map((e) => FriendRow(
              peerId: e['peer_id'] as String,
              displayName: e['display_name'] as String? ?? '친구',
              level: ((e['level'] ?? 1) as num).toInt(),
            ))
        .toList();
  }

  Future<List<FriendRankRow>> friendWeekRankings() async {
    final rows = await supabase.rpc('friend_week_rankings');
    if (rows is! List) return const [];
    return rows
        .map((e) => FriendRankRow(
              peerId: e['peer_id'] as String,
              displayName: e['display_name'] as String? ?? '친구',
              focusedSeconds: ((e['focused_seconds'] ?? 0) as num).toInt(),
              rank: ((e['rank'] ?? 0) as num).toInt(),
            ))
        .toList();
  }

  Future<void> sendFriendRequest({required String toUserId}) async {
    await supabase.from('friend_requests').insert({
      'from_user_id': supabase.auth.currentUser!.id,
      'to_user_id': toUserId,
      'status': 'pending',
    });
  }

  Future<void> acceptFriendRequest(String requestId) async {
    await supabase.rpc('accept_friend_request', params: {'p_request_id': requestId});
  }

  Future<List<Map<String, dynamic>>> pendingFriendRequestsIncoming() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const [];
    return await supabase
        .from('friend_requests')
        .select('id, from_user_id, status, created_at')
        .eq('to_user_id', uid)
        .eq('status', 'pending');
  }

  Future<List<SquadRow>> mySquads() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await supabase
        .from('squad_members')
        .select('left_at, squad_id, squads(id, name, mission_target_seconds)')
        .eq('user_id', uid);
    final out = <SquadRow>[];
    for (final r in rows) {
      if (r['left_at'] != null) continue;
      final s = r['squads'] as Map<String, dynamic>?;
      if (s == null) continue;
      out.add(SquadRow(
        id: s['id'] as String,
        name: s['name'] as String? ?? '스쿼드',
        missionTargetSeconds: ((s['mission_target_seconds'] ?? 180000) as num).toInt(),
      ));
    }
    return out;
  }

  Future<String> createSquad({
    required String name,
    int missionTargetSeconds = 180000,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    final target = missionTargetSeconds.clamp(3600, 864000); // 1시간~10일 상한
    final row = await supabase.from('squads').insert({
      'name': name.trim().isEmpty ? '우리 챌린지' : name.trim(),
      'owner_id': uid,
      'mission_target_seconds': target,
    }).select('id').single();
    final sid = row['id'] as String;
    await supabase.from('squad_members').insert({'squad_id': sid, 'user_id': uid});
    return sid;
  }

  Future<void> joinSquadById(String squadId) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('squad_members').insert({'squad_id': squadId, 'user_id': uid});
  }

  Future<void> leaveSquad(String squadId) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase
        .from('squad_members')
        .update({'left_at': DateTime.now().toUtc().toIso8601String()})
        .eq('squad_id', squadId)
        .eq('user_id', uid);
  }

  Future<Map<String, dynamic>> squadWeekProgress(String squadId) async {
    final res = await supabase.rpc(
      'squad_week_progress',
      params: {'p_squad_id': squadId},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> pullGacha({int cost = 50}) async {
    final res = await supabase.rpc('pull_cosmetic_gacha', params: {'p_cost': cost});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> equipBorder(String key) async {
    await supabase.rpc('equip_cosmetic_border', params: {'p_key': key});
  }

  Future<void> equipTitle(String titleId) async {
    await supabase.rpc('equip_title', params: {'p_title_id': titleId});
  }

  Future<List<Map<String, dynamic>>> myUnlockedTitles() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const [];
    return await supabase
        .from('user_titles')
        .select('title_id, titles(id, name_ko, min_level)')
        .eq('user_id', uid);
  }

  Future<List<CosmeticItemRow>> myCosmetics() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await supabase
        .from('user_cosmetics')
        .select('item_id, cosmetic_items(id, key, name_ko, kind, rarity)')
        .eq('user_id', uid);
    final out = <CosmeticItemRow>[];
    for (final r in rows) {
      final c = r['cosmetic_items'] as Map<String, dynamic>?;
      if (c == null) continue;
      out.add(CosmeticItemRow(
        id: c['id'] as String,
        key: c['key'] as String,
        nameKo: c['name_ko'] as String? ?? '',
        kind: c['kind'] as String? ?? '',
        rarity: c['rarity'] as String? ?? 'common',
      ));
    }
    return out;
  }
}
