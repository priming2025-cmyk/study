// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalPlansTable extends LocalPlans
    with TableInfo<$LocalPlansTable, LocalPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _itemsJsonMeta =
      const VerificationMeta('itemsJson');
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
      'items_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, title, itemsJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_plans';
  @override
  VerificationContext validateIntegrity(Insertable<LocalPlan> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('items_json')) {
      context.handle(_itemsJsonMeta,
          itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta));
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPlan(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      itemsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}items_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalPlansTable createAlias(String alias) {
    return $LocalPlansTable(attachedDatabase, alias);
  }
}

class LocalPlan extends DataClass implements Insertable<LocalPlan> {
  final String id;
  final String? title;
  final String itemsJson;
  final DateTime updatedAt;
  const LocalPlan(
      {required this.id,
      this.title,
      required this.itemsJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['items_json'] = Variable<String>(itemsJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalPlansCompanion toCompanion(bool nullToAbsent) {
    return LocalPlansCompanion(
      id: Value(id),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      itemsJson: Value(itemsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalPlan.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPlan(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String?>(json['title']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String?>(title),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalPlan copyWith(
          {String? id,
          Value<String?> title = const Value.absent(),
          String? itemsJson,
          DateTime? updatedAt}) =>
      LocalPlan(
        id: id ?? this.id,
        title: title.present ? title.value : this.title,
        itemsJson: itemsJson ?? this.itemsJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalPlan copyWithCompanion(LocalPlansCompanion data) {
    return LocalPlan(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlan(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, itemsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPlan &&
          other.id == this.id &&
          other.title == this.title &&
          other.itemsJson == this.itemsJson &&
          other.updatedAt == this.updatedAt);
}

class LocalPlansCompanion extends UpdateCompanion<LocalPlan> {
  final Value<String> id;
  final Value<String?> title;
  final Value<String> itemsJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalPlansCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPlansCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    required String itemsJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        itemsJson = Value(itemsJson),
        updatedAt = Value(updatedAt);
  static Insertable<LocalPlan> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? itemsJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (itemsJson != null) 'items_json': itemsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPlansCompanion copyWith(
      {Value<String>? id,
      Value<String?>? title,
      Value<String>? itemsJson,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return LocalPlansCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      itemsJson: itemsJson ?? this.itemsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlansCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalPlansTable localPlans = $LocalPlansTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [localPlans];
}

typedef $$LocalPlansTableCreateCompanionBuilder = LocalPlansCompanion Function({
  required String id,
  Value<String?> title,
  required String itemsJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalPlansTableUpdateCompanionBuilder = LocalPlansCompanion Function({
  Value<String> id,
  Value<String?> title,
  Value<String> itemsJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalPlansTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPlansTable> {
  $$LocalPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemsJson => $composableBuilder(
      column: $table.itemsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPlansTable> {
  $$LocalPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemsJson => $composableBuilder(
      column: $table.itemsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPlansTable> {
  $$LocalPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalPlansTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalPlansTable,
    LocalPlan,
    $$LocalPlansTableFilterComposer,
    $$LocalPlansTableOrderingComposer,
    $$LocalPlansTableAnnotationComposer,
    $$LocalPlansTableCreateCompanionBuilder,
    $$LocalPlansTableUpdateCompanionBuilder,
    (LocalPlan, BaseReferences<_$AppDatabase, $LocalPlansTable, LocalPlan>),
    LocalPlan,
    PrefetchHooks Function()> {
  $$LocalPlansTableTableManager(_$AppDatabase db, $LocalPlansTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<String> itemsJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPlansCompanion(
            id: id,
            title: title,
            itemsJson: itemsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> title = const Value.absent(),
            required String itemsJson,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPlansCompanion.insert(
            id: id,
            title: title,
            itemsJson: itemsJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalPlansTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalPlansTable,
    LocalPlan,
    $$LocalPlansTableFilterComposer,
    $$LocalPlansTableOrderingComposer,
    $$LocalPlansTableAnnotationComposer,
    $$LocalPlansTableCreateCompanionBuilder,
    $$LocalPlansTableUpdateCompanionBuilder,
    (LocalPlan, BaseReferences<_$AppDatabase, $LocalPlansTable, LocalPlan>),
    LocalPlan,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalPlansTableTableManager get localPlans =>
      $$LocalPlansTableTableManager(_db, _db.localPlans);
}
