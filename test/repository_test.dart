import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/backup.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';

void main() {
  sqfliteFfiInit();
  test('元数据损坏不能用初始库覆盖原记录', () async {
    final dir = await Directory.systemTemp.createTemp('lianji-corrupt-meta-');
    final repo = await SqliteTrainingRepository.open(
      factory: databaseFactoryFfi,
      path: '${dir.path}/test.db',
    );
    await repo.load();
    final before = await repo.database.query('records');
    await repo.database.delete('metadata');
    await expectLater(repo.load(), throwsFormatException);
    expect(await repo.database.query('records'), before);
    await repo.close();
  });
  test('SQLite 关闭重开保留草稿、完成组、外观和暂停状态', () async {
    final dir = await Directory.systemTemp.createTemp('lianji-db-');
    final path = '${dir.path}/test.db';
    var repo = await SqliteTrainingRepository.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final c = AppController(repo, await repo.load());
    final id = await c.start();
    await c.addExercise(id, c.data.exercises.first);
    final e = c.data.active!.exercises.first, s = e.sets.first;
    await c.editSet(id, e.id, s.id, {'weight': 40, 'reps': 8});
    await c.completeSet(id, e.id, s.id);
    await c.pause(id);
    await c.change((d) {
      d.settings['brand'] = 'sage';
      d.settings['appearance'] = 'dark';
    });
    await repo.close();
    repo = await SqliteTrainingRepository.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final restored = await repo.load();
    expect(restored.active!.completedSets, 1);
    expect(restored.active!.paused, true);
    expect(restored.active!.exercises.first.sets.first.weight, 40);
    expect(restored.settings['brand'], 'sage');
    c.dispose();
    await repo.close();
  });
  test('SQLite 事务错误回滚，不破坏原数据', () async {
    final dir = await Directory.systemTemp.createTemp('lianji-rollback-');
    final repo = await SqliteTrainingRepository.open(
      factory: databaseFactoryFfi,
      path: '${dir.path}/test.db',
    );
    final original = await repo.load();
    final broken = original.copy();
    broken.exercises.add(Exercise(broken.exercises.first.toJson()));
    await expectLater(repo.save(broken), throwsA(anything));
    expect((await repo.load()).toJson(), original.toJson());
    await repo.close();
  });
  test('恢复前备份生成且恢复故障保留当前库', () async {
    final dir = await Directory.systemTemp.createTemp('lianji-restore-');
    final repo = await SqliteTrainingRepository.open(
      factory: databaseFactoryFfi,
      path: '${dir.path}/test.db',
    );
    final c = AppController(repo, await repo.load());
    await c.start();
    final before = c.data.copy();
    final incoming = initialData();
    incoming.settings['brand'] = 'blue';
    await c.restore(
      BackupCodec.encode(incoming),
      Directory('${dir.path}/safety'),
    );
    final files = await Directory('${dir.path}/safety').list().toList();
    expect(files.length, 1);
    expect(
      BackupCodec.decode(
        await File(files.single.path).readAsString(),
      ).sessions.length,
      before.sessions.length,
    );
    expect(c.data.sessions, isEmpty);
    expect(c.data.settings['brand'], 'blue');
    await expectLater(
      c.restore('{bad}', Directory('${dir.path}/safety')),
      throwsA(anything),
    );
    expect(c.data.settings['brand'], 'blue');
    await repo.close();
    c.dispose();
  });
}
