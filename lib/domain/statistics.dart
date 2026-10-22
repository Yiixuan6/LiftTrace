import 'models.dart';

enum TimeFilter { days7, days30, days90, week, month, year, all }

const filterLabels = ['最近 7 天', '最近 30 天', '最近 90 天', '本周', '本月', '本年', '全部时间'];
DateTime? rangeStart(TimeFilter filter, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (filter) {
    TimeFilter.days7 => today.subtract(const Duration(days: 6)),
    TimeFilter.days30 => today.subtract(const Duration(days: 29)),
    TimeFilter.days90 => today.subtract(const Duration(days: 89)),
    TimeFilter.week => today.subtract(Duration(days: today.weekday - 1)),
    TimeFilter.month => DateTime(now.year, now.month),
    TimeFilter.year => DateTime(now.year),
    TimeFilter.all => null,
  };
}

class Statistics {
  int sessions = 0, sets = 0;
  double volume = 0, cardioSeconds = 0;
  Duration duration = Duration.zero;
  final days = <String>{};
  final muscles = <String, int>{};
  final dailyVolume = <String, double>{};
  final weights = <String, List<(DateTime, double)>>{};
  static Statistics calculate(
    AppData data,
    TimeFilter filter,
    DateTime now, {
    String? exerciseId,
  }) {
    final result = Statistics();
    final start = rangeStart(filter, now);
    bool included(DateTime date) =>
        (start == null || !date.toLocal().isBefore(start)) &&
        !date.isAfter(now);
    for (final session in data.sessions.where((s) => !s.deleted)) {
      var valid = false;
      for (final move in session.exercises) {
        if (exerciseId != null && move.data['exerciseId'] != exerciseId) {
          continue;
        }
        for (final set in move.sets.where((s) => s.completed)) {
          final at = DateTime.parse(
            set.data['completedAt'] as String? ??
                session.data['startedAt'] as String,
          );
          if (!included(at)) continue;
          valid = true;
          final day = dateKey(at.toLocal());
          result.days.add(day);
          result.sets++;
          final volume = set.volume(move.exercise.kind);
          result.volume += volume;
          result.dailyVolume.update(
            day,
            (v) => v + volume,
            ifAbsent: () => volume,
          );
          if (move.exercise.kind == LoadKind.cardio) {
            result.cardioSeconds += set.seconds ?? 0;
          }
          result.muscles.update(
            move.exercise.muscle,
            (v) => v + 1,
            ifAbsent: () => 1,
          );
          if ([
                LoadKind.external,
                LoadKind.dumbbell,
              ].contains(move.exercise.kind) &&
              set.weight != null) {
            result.weights
                .putIfAbsent(move.data['exerciseId'] as String, () => [])
                .add((at, set.weight!));
          }
        }
      }
      if (valid) {
        if (!session.active) result.sessions++;
        // Clip session intervals to selected range; explicit pauses are removed.
        final end = session.endedAt ?? now;
        final begin = start != null && session.startedAt.isBefore(start)
            ? start
            : session.startedAt;
        var milliseconds = end.difference(begin).inMilliseconds;
        for (final p in session.pauses) {
          final a = DateTime.parse(p['start'] as String);
          final b = p['end'] == null ? end : DateTime.parse(p['end'] as String);
          final overlapStart = a.isAfter(begin) ? a : begin;
          final overlapEnd = b.isBefore(end) ? b : end;
          if (overlapEnd.isAfter(overlapStart)) {
            milliseconds -= overlapEnd.difference(overlapStart).inMilliseconds;
          }
        }
        result.duration += Duration(
          milliseconds: milliseconds.clamp(0, 1 << 52),
        );
      }
    }
    for (final points in result.weights.values) {
      points.sort((a, b) => a.$1.compareTo(b.$1));
    }
    return result;
  }
}
