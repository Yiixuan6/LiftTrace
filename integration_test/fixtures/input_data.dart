import 'package:lianji/domain/models.dart';

AppData inputFixture(int history) {
  final d = initialData();
  for (var i = 0; i <= history; i++) {
    final s = Session.start('合成训练', [
      for (var j = 0; j < (i == history ? 6 : 1); j++)
        WorkoutExercise.fromExercise(d.exercises.first),
    ], at: DateTime.now().subtract(Duration(days: history - i)));
    for (final move in s.exercises) {
      move.data['sets'] = [
        for (var k = 0; k < 8; k++)
          (WorkoutSet.empty()..data.addAll({'weight': 40, 'reps': 8})).toJson(),
      ];
    }
    if (i < history) s.data['endedAt'] = s.data['startedAt'];
    d.sessions.add(s);
  }
  return d;
}
