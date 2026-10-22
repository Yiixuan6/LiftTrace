import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/models.dart';
import 'backup.dart';

abstract interface class TrainingRepository {
  Future<AppData> load();
  Future<void> save(AppData data);
  Future<void> close();
}

/// Versioned document records in SQLite. Session documents atomically include
/// all exercise snapshots and sets; no partial session can become visible.
class SqliteTrainingRepository implements TrainingRepository {
  SqliteTrainingRepository(this.database);
  final Database database;
  static Future<SqliteTrainingRepository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path ?? p.join(await getDatabasesPath(), 'lianji.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.rawQuery('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = FULL');
        },
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE records (kind TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(kind,id))',
          );
          await db.execute(
            "CREATE UNIQUE INDEX one_active_session ON records(active) WHERE kind = 'session' AND active = 1",
          );
          await db.execute(
            'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        },
        onUpgrade: (db, old, version) async {
          // Future versions add explicit, tested migrations here. Never recreate.
          throw StateError('缺少数据库 $old → $version 的迁移');
        },
      ),
    );
    return SqliteTrainingRepository(db);
  }

  @override
  Future<AppData> load() async {
    final meta = await database.query('metadata');
    if (meta.isEmpty) {
      if ((await database.query('records', limit: 1)).isNotEmpty) {
        throw const FormatException('本地元数据缺失，已停止读取以保护记录');
      }
      final data = initialData();
      await save(data);
      return data;
    }
    final map = {
      for (final row in meta)
        row['key'] as String: jsonDecode(row['value'] as String),
    };
    final rows = await database.query('records');
    List<Json> byKind(String kind) => rows
        .where((r) => r['kind'] == kind)
        .map((r) => jsonDecode(r['payload'] as String) as Json)
        .toList();
    final data = AppData.fromJson({
      'exercises': byKind('exercise'),
      'templates': byKind('template'),
      'sessions': byKind('session'),
      'measurements': byKind('measurement'),
      'settings': map['settings'],
      'schedule': map['schedule'],
      'revision': map['revision'],
    });
    BackupCodec.validate(data);
    return data;
  }

  @override
  Future<void> save(AppData data) => database.transaction((tx) async {
    if (data.sessions.where((s) => s.active).length > 1) {
      throw StateError('同一设备只能有一个进行中训练');
    }
    // Replacing the set is required for full restore. The transaction also
    // guarantees rollback of the original data on any insert failure.
    await tx.delete('records');
    final batch = tx.batch();
    void add(String kind, List<Record> records) {
      for (final r in records) {
        batch.insert('records', {
          'kind': kind,
          'id': r.id,
          'payload': jsonEncode(r.toJson()),
          'active': r is Session && r.active ? 1 : 0,
        });
      }
    }

    add('exercise', data.exercises);
    add('template', data.templates);
    add('session', data.sessions);
    add('measurement', data.measurements);
    for (final entry in {
      'settings': data.settings,
      'schedule': data.schedule,
      'revision': data.revision,
    }.entries) {
      batch.insert('metadata', {
        'key': entry.key,
        'value': jsonEncode(entry.value),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  });
  @override
  Future<void> close() => database.close();
}

class MemoryTrainingRepository implements TrainingRepository {
  MemoryTrainingRepository([AppData? initial]) : _data = initial ?? AppData();
  AppData _data;
  @override
  Future<AppData> load() async => _data.copy();
  @override
  Future<void> save(AppData data) async => _data = data.copy();
  @override
  Future<void> close() async {}
}
