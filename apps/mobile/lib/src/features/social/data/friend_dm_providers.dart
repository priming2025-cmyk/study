import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/friend_dm_repository.dart';
import '../domain/friend_dm_models.dart';

final friendDmRepositoryProvider = Provider<FriendDmRepository>((ref) {
  final repo = FriendDmRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final friendDmThreadsProvider =
    FutureProvider.autoDispose<List<FriendDmThread>>((ref) async {
  final repo = ref.watch(friendDmRepositoryProvider);
  await repo.ensureSubscribed();
  return repo.listThreads();
});

final friendDmActivePeerProvider = StateProvider<String?>((ref) => null);
