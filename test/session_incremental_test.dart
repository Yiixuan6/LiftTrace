import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/domain/statistics.dart';
import 'input_benchmark_test.dart' show inputFixture;

void main() {
  sqfliteFfiInit();
  for (final history in [200, 1000]) {
    test('$history历史：击键只更新当前会话，串行保存与完整重开一致', () async {
      final repo = await SqliteTrainingRepository.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(repo.close);
      await repo.save(inputFixture(history));
      final c = AppController(repo, await repo.load());
      addTearDown(c.dispose);
      final session = c.data.active!, move = session.exercises.first;
      final set = move.sets.first;
      final untouched = c.data.sessions.first;
      final otherRows = await repo.database.query(
        'records',
        where: 'id != ?',
        whereArgs: [session.id],
      );
      await repo.database.execute('CREATE TABLE audit (operation TEXT)');
      for (final op in ['INSERT', 'UPDATE', 'DELETE']) {
        await repo.database.execute(
          "CREATE TRIGGER audit_$op AFTER $op ON records BEGIN INSERT INTO audit VALUES ('$op'); END",
        );
      }
      await Future.wait([
        for (var i = 0; i < 20; i++)
          c.editSet(session.id, move.id, set.id, {'weight': 30 + i / 10}),
        c.editSet(session.id, move.id, set.id, {'note': '中文已提交备注'}),
        c.completeSet(session.id, move.id, set.id),
      ]);
      expect(
        await repo.database.query('audit'),
        everyElement({'operation': 'UPDATE'}),
      );
      expect((await repo.database.query('audit')).length, 22);
      expect(
        await repo.database.query(
          'records',
          where: 'id != ?',
          whereArgs: [session.id],
        ),
        otherRows,
      );
      expect(identical(c.data.sessions.first, untouched), isTrue);
      expect((await repo.load()).toJson(), c.data.toJson());
      expect(c.data.active!.completedSets, 1);
      expect(
        Statistics.calculate(c.data, TimeFilter.all, DateTime.now()).volume,
        closeTo(31.9 * 8, .00001),
      );
      expect(c.data.active!.exercises.first.sets.first.data['note'], '中文已提交备注');
    });
  }

  test('元数据更新失败：会话及修订号一起回滚，后续重试可恢复', () async {
    final repo = await SqliteTrainingRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(repo.close);
    await repo.save(inputFixture(1));
    final c = AppController(repo, await repo.load());
    addTearDown(c.dispose);
    final before = c.data.toJson();
    final s = c.data.active!, e = s.exercises.first, row = e.sets.first;
    await repo.database.execute(
      "CREATE TRIGGER fail_revision BEFORE UPDATE ON metadata WHEN NEW.key = 'revision' BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
    );
    await expectLater(
      c.editSet(s.id, e.id, row.id, {'weight': 55}),
      throwsA(anything),
    );
    expect(c.data.toJson(), before);
    expect((await repo.load()).toJson(), before);
    await expectLater(c.flushInputs(), throwsStateError);
    await repo.database.execute('DROP TRIGGER fail_revision');
    await c.editSet(s.id, e.id, row.id, {'weight': 55});
    await c.flushInputs();
    expect((await repo.load()).active!.exercises.first.sets.first.weight, 55);
  });

  test('会话增量写入保留唯一活动约束且拒绝不存在的ID', () async {
    final repo = await SqliteTrainingRepository.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(repo.close);
    final d = inputFixture(1);
    await repo.save(d);
    final before = (await repo.load()).toJson();
    final clash = Session(d.sessions.first.toJson())..data['endedAt'] = null;
    await expectLater(
      repo.saveSession(clash, d.revision + 1),
      throwsA(anything),
    );
    await expectLater(
      repo.saveSession(Session.start('missing', []), 999),
      throwsStateError,
    );
    expect((await repo.load()).toJson(), before);
  });

  test('保存屏障等待尚未完成的事务，不把排队当成已保存', () async {
    final d = inputFixture(0), repo = _GatedRepo(inputFixture(0));
    await repo.save(d);
    final c = AppController(repo, await repo.load());
    addTearDown(c.dispose);
    final s = c.data.active!, e = s.exercises.first;
    final saving = c.editSet(s.id, e.id, e.sets.first.id, {'weight': 55});
    var flushed = false;
    final barrier = c.flushInputs().then((_) => flushed = true);
    await Future<void>.delayed(Duration.zero);
    expect(flushed, isFalse);
    expect(c.data.active!.exercises.first.sets.first.weight, 40);
    repo.gate.complete();
    await saving;
    await barrier;
    expect(flushed, isTrue);
    expect((await repo.load()).active!.exercises.first.sets.first.weight, 55);
  });
}

class _GatedRepo extends MemoryTrainingRepository {
  _GatedRepo(super.initial);
  final gate = Completer<void>();
  @override
  Future<void> saveSession(Session session, int revision) async {
    await gate.future;
    await super.saveSession(session, revision);
  }
}
