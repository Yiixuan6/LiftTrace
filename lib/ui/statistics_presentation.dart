import '../domain/models.dart';
import '../domain/statistics.dart';

/// Pure presentation projections. Never persist or change business totals.
class VolumeBucket {
  const VolumeBucket(this.date, this.volume);
  final DateTime date;
  final double volume;
}

List<VolumeBucket> volumeBuckets(Map<String, double> daily, TimeFilter filter) {
  final result = <String, double>{};
  for (final entry in daily.entries) {
    var at = DateTime.parse(entry.key);
    if (filter == TimeFilter.days90) {
      at = at.subtract(Duration(days: at.weekday - 1));
    } else if (filter == TimeFilter.year || filter == TimeFilter.all) {
      at = DateTime(at.year, at.month);
    }
    result.update(
      dateKey(at),
      (v) => v + entry.value,
      ifAbsent: () => entry.value,
    );
  }
  final dates = result.keys.toList()..sort();
  return dates.map((d) => VolumeBucket(DateTime.parse(d), result[d]!)).toList();
}

class WeightPoint {
  const WeightPoint(this.setId, this.at, this.weight);
  final String setId;
  final DateTime at;
  final double weight;
}

class WeightSeries {
  WeightSeries(this.exerciseId, this.name, this.kind);
  final String exerciseId, name;
  final LoadKind kind;
  final List<WeightPoint> points = [];
  String get key => '$exerciseId/${kind.name}';
  bool get supportsWeight =>
      kind == LoadKind.external || kind == LoadKind.dumbbell;
  String get unitLabel => kind == LoadKind.dumbbell ? '单只重量 kg' : '总外部重量 kg';
}

List<WeightSeries> weightSeries(AppData data, TimeFilter filter, DateTime now) {
  final start = rangeStart(filter, now);
  final series = <String, WeightSeries>{};
  void add(String id, String name, LoadKind kind) {
    series.putIfAbsent('$id/${kind.name}', () => WeightSeries(id, name, kind));
  }

  for (final e in data.exercises.where((e) => !e.deleted)) {
    add(e.id, e.name, e.kind);
  }
  for (final session in data.sessions.where((s) => !s.deleted)) {
    for (final move in session.exercises) {
      final id = move.data['exerciseId'] as String;
      final e = move.exercise;
      add(id, e.name, e.kind);
      final group = series['$id/${e.kind.name}']!;
      if (!group.supportsWeight) continue;
      for (final set in move.sets.where(
        (s) => s.completed && s.weight != null,
      )) {
        final at = DateTime.parse(
          set.data['completedAt'] as String? ??
              session.data['startedAt'] as String,
        );
        if ((start == null || !at.toLocal().isBefore(start)) &&
            !at.isAfter(now)) {
          group.points.add(WeightPoint(set.id, at, set.weight!));
        }
      }
    }
  }
  for (final group in series.values) {
    // Dart's sort need not be stable; preserve source order for equal timestamps.
    final indexed = group.points.indexed.toList()
      ..sort((a, b) {
        final time = a.$2.at.compareTo(b.$2.at);
        return time == 0 ? a.$1.compareTo(b.$1) : time;
      });
    group.points
      ..clear()
      ..addAll(indexed.map((p) => p.$2));
  }
  return series.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}
