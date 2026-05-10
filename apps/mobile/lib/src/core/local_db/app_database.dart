import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

part 'app_database.g.dart';

QueryExecutor _openStudyExecutor() {
  if (kIsWeb) {
    return driftDatabase(
      name: 'study_up',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
      ),
    );
  }
  return driftDatabase(name: 'study_up');
}

class LocalPlans extends Table {
  TextColumn get id => text()(); // yyyy-mm-dd
  TextColumn get title => text().nullable()();
  TextColumn get itemsJson => text()(); // MVP: store as JSON for quick iteration
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [LocalPlans])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openStudyExecutor());

  @override
  int get schemaVersion => 1;

  Future<void> upsertLocalPlan({
    required String id,
    required String itemsJson,
    String? title,
  }) async {
    final now = DateTime.now();
    await into(localPlans).insertOnConflictUpdate(
      LocalPlansCompanion.insert(
        id: id,
        title: Value(title),
        itemsJson: itemsJson,
        updatedAt: now,
      ),
    );
  }
}
