import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/domain/statistics.dart';
import 'package:lianji/ui/statistics_presentation.dart';

AppData statisticsFixture() {
  final d = initialData();
  final at = DateTime(2026, 10, 19, 10);
  final external = WorkoutExercise.fromExercise(d.exercises.first);
  for (final weight in [30, 40]) {
    final set = WorkoutSet.empty();
    set.data.addAll({
      'weight': weight,
      'reps': 8,
      'completed': true,
      'completedAt': at
          .add(const Duration(minutes: 5))
          .toUtc()
          .toIso8601String(),
    });
    (external.data['sets'] as List).add(set.toJson());
  }
  final dumbbell = WorkoutExercise.fromExercise(d.exercises.first);
  (dumbbell.data['snapshot'] as Json)['kind'] = 'dumbbell';
  dumbbell.sets.first.data.addAll({
    'weight': 5,
    'sideMode': 'bilateral',
    'leftReps': 8,
    'rightReps': 8,
    'completed': true,
    'completedAt': at.toUtc().toIso8601String(),
  });
  final assisted = WorkoutExercise.fromExercise(d.exercises[4]);
  assisted.sets.first.data.addAll({
    'assistance': 20,
    'weight': 900,
    'reps': 8,
    'completed': true,
    'completedAt': at.toUtc().toIso8601String(),
  });
  final s = Session.start('合成统计记录', [external, dumbbell, assisted], at: at);
  s.data['endedAt'] = at
      .add(const Duration(minutes: 30))
      .toUtc()
      .toIso8601String();
  d.sessions.add(s);
  return d;
}

void main() {
  final now = DateTime(2026, 10, 20, 12);
  test('七种时间范围展示汇总保持业务总量与档案字节结构', () {
    final d = statisticsFixture(),
        before = jsonEncode(statisticsFixture().settings);
    final raw = jsonEncode(d.toJson());
    for (final filter in TimeFilter.values) {
      final stats = Statistics.calculate(d, filter, now);
      expect(stats.volume, 640);
      expect(stats.sets, 4);
      expect(
        volumeBuckets(
          stats.dailyVolume,
          filter,
        ).fold(0.0, (a, b) => a + b.volume),
        640,
      );
      weightSeries(d, filter, now);
    }
    expect(jsonEncode(d.toJson()), raw);
    expect(jsonEncode(d.settings), before);
  });
  test('周一起始跨周与跨月合并保真', () {
    final map = {
      '2026-10-18': 10.0,
      '2026-10-19': 20.0,
      '2026-10-20': 30.0,
      '2026-11-01': 40.0,
    };
    final weeks = volumeBuckets(map, TimeFilter.days90);
    expect(weeks.map((b) => dateKey(b.date)), [
      '2026-10-12',
      '2026-10-19',
      '2026-10-26',
    ]);
    expect(weeks.map((b) => b.volume), [10, 50, 40]);
    expect(volumeBuckets(map, TimeFilter.year).map((b) => b.volume), [60, 40]);
    expect(volumeBuckets({}, TimeFilter.all), isEmpty);
  });
  test('同动作混合口径分开、同日每组保留且同时间顺序稳定', () {
    final d = statisticsFixture();
    final series = weightSeries(d, TimeFilter.days30, now);
    final id = d.exercises.first.id;
    final external = series.singleWhere(
      (s) => s.exerciseId == id && s.kind == LoadKind.external,
    );
    final dumbbell = series.singleWhere(
      (s) => s.exerciseId == id && s.kind == LoadKind.dumbbell,
    );
    expect(external.points.map((p) => p.weight), [30, 40]);
    expect(external.points.map((p) => p.setId).toSet().length, 2);
    expect(dumbbell.points.single.weight, 5);
    expect(
      series.singleWhere((s) => s.kind == LoadKind.assisted).points,
      isEmpty,
    );
    expect(external.key, isNot(dumbbell.key));
  });
  test('删除、草稿、未来与范围外记录不混入趋势；历史动作仍可查看', () {
    final d = statisticsFixture();
    d.exercises.first.data['deleted'] = true;
    final move = d.sessions.first.exercises.first;
    final completed = move.sets.where((s) => s.completed).toList();
    completed.first.data['deleted'] = true;
    completed.last.data['completedAt'] = now
        .add(const Duration(days: 1))
        .toUtc()
        .toIso8601String();
    expect(
      weightSeries(d, TimeFilter.days7, now)
          .singleWhere(
            (s) =>
                s.exerciseId == move.data['exerciseId'] &&
                s.kind == LoadKind.external,
          )
          .points,
      isEmpty,
    );
    completed.last.data['completedAt'] = now
        .subtract(const Duration(days: 60))
        .toUtc()
        .toIso8601String();
    expect(
      weightSeries(d, TimeFilter.days7, now)
          .singleWhere(
            (s) =>
                s.exerciseId == move.data['exerciseId'] &&
                s.kind == LoadKind.external,
          )
          .points,
      isEmpty,
    );
    expect(
      weightSeries(d, TimeFilter.days90, now)
          .singleWhere(
            (s) =>
                s.exerciseId == move.data['exerciseId'] &&
                s.kind == LoadKind.external,
          )
          .points
          .length,
      1,
    );
    d.sessions.first.data['deleted'] = true;
    expect(
      weightSeries(
        d,
        TimeFilter.all,
        now,
      ).where((s) => s.exerciseId == move.data['exerciseId']),
      isEmpty,
    );
  });
}
