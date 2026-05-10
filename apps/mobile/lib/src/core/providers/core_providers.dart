import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local_db/app_database.dart';
import '../../features/family/data/family_repository.dart';
import '../../features/plan/data/plan_repository.dart';
import '../../features/session/data/session_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(database: ref.watch(appDatabaseProvider));
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return const SessionRepository();
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return const FamilyRepository();
});
