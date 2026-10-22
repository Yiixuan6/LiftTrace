import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/backup.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/domain/statistics.dart';

void main() {
  test('跨日、筛选、辅助/有氧、跳过与删除的统计口径', () {
    final d = initialData(),
        now = DateTime(2026, 10, 19, 12),
        start = DateTime(2026, 10, 18, 23, 50);
    final moves = [
      d.exercises[0],
      d.exercises[1],
      d.exercises[4],
      d.exercises[11],
    ].map(WorkoutExercise.fromExercise).toList();
    final s = Session.start('跨日记录', moves, at: start);
    s.data['endedAt'] = DateTime(2026, 10, 19, 0, 20).toUtc().toIso8601String();
    s.pauses.add({
      'start': DateTime(2026, 10, 18, 23, 58).toUtc().toIso8601String(),
      'end': DateTime(2026, 10, 19, 0, 3).toUtc().toIso8601String(),
    });
    d.sessions.add(s);
    final fields = [
      {'weight': 10, 'reps': 10},
      {'weight': 5, 'sideMode': 'bilateral', 'leftReps': 8, 'rightReps': 8},
      {'assistance': 20, 'reps': 6},
      {'seconds': 120, 'distance': .3},
    ];
    for (var i = 0; i < 4; i++) {
      s.exercises[i].sets.first.data.addAll({
        ...fields[i],
        'completed': true,
        'completedAt':
            (i == 0
                    ? DateTime(2026, 10, 18, 23, 55)
                    : DateTime(2026, 10, 19, 0, 10))
                .toUtc()
                .toIso8601String(),
      });
    }
    s.exercises.first.data['skipped'] = true;
    final all = Statistics.calculate(d, TimeFilter.all, now);
    expect(all.volume, 180);
    expect(all.cardioSeconds, 120);
    expect(all.sets, 4);
    expect(all.sessions, 1);
    expect(all.days.length, 2);
    expect(all.duration.inMinutes, 25);
    expect(all.muscles.values.reduce((a, b) => a + b), 4);
    final week = Statistics.calculate(d, TimeFilter.week, now);
    expect(week.volume, 80);
    expect(week.sets, 3);
    expect(week.days.length, 1);
    expect(week.duration.inMinutes, 17);
    s.data['deleted'] = true;
    expect(Statistics.calculate(d, TimeFilter.all, now).sets, 0);
  });
  test('草稿损坏、日期重复及设备任务迁移受到保护', () {
    final d = initialData();
    d.settings['restDeadline'] = stamp();
    d.settings['restRemaining'] = 60;
    final clean = BackupCodec.decode(BackupCodec.encode(d));
    expect(clean.settings.containsKey('restDeadline'), false);
    expect(clean.settings.containsKey('restRemaining'), false);
    final s = Session.start('损坏草稿', [
      WorkoutExercise.fromExercise(d.exercises.first),
    ]);
    d.sessions.add(s);
    s.exercises.first.sets.first.data['weight'] = 'bad';
    expect(
      () => BackupCodec.decode(BackupCodec.encode(d)),
      throwsFormatException,
    );
    d.sessions.clear();
    d.measurements.addAll([
      Record({...Record.base(), 'date': '2026-10-19', 'weight': 65}),
      Record({...Record.base(), 'date': '2026-10-19', 'weight': 66}),
    ]);
    expect(
      () => BackupCodec.decode(BackupCodec.encode(d)),
      throwsFormatException,
    );
  });
  test('历史训练新增完成组保留原训练日期', () async {
    final d = initialData(), at = DateTime.utc(2026, 10, 10);
    final s = Session.start('历史', [
      WorkoutExercise.fromExercise(initialData().exercises.first),
    ], at: at);
    s.data['endedAt'] = at.add(const Duration(hours: 1)).toIso8601String();
    d.sessions.add(s);
    final e = s.exercises.first, set = e.sets.first;
    set.data.addAll({'weight': 20, 'reps': 8});
    final c = AppController(MemoryTrainingRepository(d), d);
    await c.completeSet(s.id, e.id, set.id);
    expect(
      c.data.sessions.first.exercises.first.sets.first.data['completedAt'],
      s.data['endedAt'],
    );
    c.dispose();
  });
  test('初始库只有动作和示例模板，训练与身体为空', () {
    final d = initialData();
    expect(d.sessions, isEmpty);
    expect(d.measurements, isEmpty);
    expect(d.templates.length, 6);
  });
  test('哑铃按左右实际次数之和，辅助、有氧和未完成不计负重', () {
    final s = WorkoutSet({
      ...WorkoutSet.empty().toJson(),
      'weight': 5,
      'leftReps': 8,
      'rightReps': 8,
      'reps': 8,
      'completed': true,
    });
    expect(s.volume(LoadKind.dumbbell), 80);
    expect(s.volume(LoadKind.external), 40);
    expect(s.volume(LoadKind.assisted), 0);
    expect(s.volume(LoadKind.cardio), 0);
    s.data['completed'] = false;
    expect(s.volume(LoadKind.external), 0);
  });
  test('复制组保留数据，清除完成状态和时间', () {
    final a = WorkoutSet({
      ...WorkoutSet.empty().toJson(),
      'weight': 20,
      'reps': 8,
      'completed': true,
      'completedAt': stamp(),
    });
    final b = a.duplicate();
    expect(b.id, isNot(a.id));
    expect(b.completed, false);
    expect(b.data['completedAt'], null);
    expect(b.weight, 20);
  });
  test('训练时长扣暂停，正常休息保留', () {
    final t = DateTime.utc(2026, 10, 19, 2);
    final s = Session.start('测试', [], at: t);
    s.pauses.add({
      'start': t.add(const Duration(minutes: 5)).toIso8601String(),
      'end': t.add(const Duration(minutes: 8)).toIso8601String(),
    });
    expect(s.duration(t.add(const Duration(minutes: 20))).inMinutes, 17);
    s.pauses.add({
      'start': t.add(const Duration(minutes: 15)).toIso8601String(),
      'end': null,
    });
    expect(s.duration(t.add(const Duration(minutes: 20))).inMinutes, 12);
  });
  test('非法负数、非整数次数、缺少哑铃口径和有氧时长被拒绝', () {
    final s = WorkoutSet.empty();
    s.data.addAll({'weight': -1, 'reps': 8});
    expect(s.validate(LoadKind.external), isNotNull);
    s.data.addAll({'weight': 5, 'reps': 1.5});
    expect(s.validate(LoadKind.external), isNotNull);
    s.data['reps'] = 8;
    expect(s.validate(LoadKind.dumbbell), isNotNull);
    expect(s.validate(LoadKind.cardio), isNotNull);
  });
  test('模板快照与训练隔离，模板更改/删除不改历史', () {
    final d = initialData(), t = initialData().templates.first;
    final s = Session.start(t.name, t.freshExercises());
    final before = jsonEncode(s.toJson());
    t.data['exercises'] = [];
    t.data['deleted'] = true;
    expect(jsonEncode(s.toJson()), before);
    expect(d.sessions, isEmpty);
  });
  test('并发开始只生成一个活动会话，连续完成只计一组', () async {
    final repo = MemoryTrainingRepository(initialData());
    final c = AppController(repo, await repo.load());
    final ids = await Future.wait([c.start(), c.start(), c.start()]);
    expect(ids.toSet().length, 1);
    expect(c.data.sessions.length, 1);
    await c.addExercise(ids.first, c.data.exercises.first);
    final e = c.data.active!.exercises.first, set = e.sets.first;
    await c.editSet(ids.first, e.id, set.id, {'weight': 20, 'reps': 8});
    await Future.wait([
      c.completeSet(ids.first, e.id, set.id),
      c.completeSet(ids.first, e.id, set.id),
    ]);
    expect(c.data.active!.completedSets, 1);
    expect(
      Statistics.calculate(c.data, TimeFilter.all, DateTime.now()).volume,
      160,
    );
    expect(
      Statistics.calculate(c.data, TimeFilter.all, DateTime.now()).sessions,
      0,
    );
    await c.finish(ids.first);
    expect(
      Statistics.calculate(c.data, TimeFilter.all, DateTime.now()).sessions,
      1,
    );
    c.dispose();
  });
  test('完整备份往返，损坏/未知版本拒绝', () {
    final d = initialData();
    final raw = BackupCodec.encode(d);
    expect(BackupCodec.decode(raw).toJson(), d.toJson());
    final envelope = jsonDecode(raw) as Json;
    envelope['payload'] = '{}';
    expect(
      () => BackupCodec.decode(jsonEncode(envelope)),
      throwsFormatException,
    );
    envelope['version'] = 999;
    expect(
      () => BackupCodec.decode(jsonEncode(envelope)),
      throwsFormatException,
    );
  });
  test('空身体数据保留 null；重复 ID 和多个活动会话拒绝', () {
    final d = initialData();
    d.measurements.add(
      Record({
        ...Record.base(),
        'date': '2026-10-19',
        'weight': 65,
        'waist': null,
      }),
    );
    expect(
      BackupCodec.decode(
        BackupCodec.encode(d),
      ).measurements.first.data['waist'],
      null,
    );
    d.sessions.addAll([Session.start('A', []), Session.start('B', [])]);
    expect(
      () => BackupCodec.decode(BackupCodec.encode(d)),
      throwsFormatException,
    );
  });
  test('周一起始与日期筛选', () {
    final now = DateTime(2026, 10, 21, 12);
    expect(rangeStart(TimeFilter.week, now), DateTime(2026, 10, 19));
    expect(rangeStart(TimeFilter.days7, now), DateTime(2026, 10, 15));
  });
}
