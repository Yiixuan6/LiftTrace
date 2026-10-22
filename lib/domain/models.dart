import 'dart:convert';
import 'package:uuid/uuid.dart';

typedef Json = Map<String, dynamic>;
String newId() => const Uuid().v4();
String stamp() => DateTime.now().toUtc().toIso8601String();
String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum LoadKind { external, dumbbell, assisted, cardio, unknown }

enum BrandTheme { orange, blue, sage }

enum Appearance { system, light, dark }

/// All business records carry identity and tombstones. Exercise data within a
/// session is a deep snapshot, never a live reference to a template/catalog.
class Record {
  Record(this.data);
  final Json data;
  String get id => data['id'] as String;
  bool get deleted => data['deleted'] == true;
  Json toJson() => jsonDecode(jsonEncode(data)) as Json;
  void touch() => data['updatedAt'] = stamp();
  static Json base() => {
    'id': newId(),
    'createdAt': stamp(),
    'updatedAt': stamp(),
    'deleted': false,
  };
}

class Exercise extends Record {
  Exercise(super.data);
  factory Exercise.create(
    String name,
    String muscle,
    String equipment,
    LoadKind kind,
  ) => Exercise({
    ...Record.base(),
    'name': name.trim(),
    'muscle': muscle,
    'equipment': equipment,
    'kind': kind.name,
    'favorite': false,
  });
  String get name => data['name'] as String;
  String get muscle => data['muscle'] as String;
  String get equipment => data['equipment'] as String;
  LoadKind get kind => LoadKind.values.byName(data['kind'] as String);
  bool get favorite => data['favorite'] == true;
}

class WorkoutSet extends Record {
  WorkoutSet(super.data);
  factory WorkoutSet.empty() =>
      WorkoutSet({...Record.base(), 'completed': false});
  bool get completed => data['completed'] == true;
  double? value(String key) => (data[key] as num?)?.toDouble();
  int? get reps => (data['reps'] as num?)?.toInt();
  double? get weight => value('weight');
  double? get seconds => value('seconds');
  String? validateFields() {
    for (final key in [
      'weight',
      'assistance',
      'seconds',
      'distance',
      'speed',
      'resistance',
      'leftReps',
      'rightReps',
      'reps',
    ]) {
      final v = data[key];
      if (v != null && (v is! num || !v.isFinite || v < 0)) {
        return '数值必须是有限的非负数';
      }
    }
    for (final key in ['reps', 'leftReps', 'rightReps']) {
      final n = data[key] as num?;
      if (n != null && n != n.roundToDouble()) return '次数必须为整数';
    }
    for (final key in ['note', 'feeling', 'bodyState', 'sideMode']) {
      if (data[key] != null && data[key] is! String) return '文本字段无效';
    }
    if (data['sideMode'] != null &&
        !['bilateral', 'unilateral'].contains(data['sideMode'])) {
      return '单双侧方式无效';
    }
    if (data['feeling'] != null &&
        !['轻松', '适中', '吃力', '接近力竭'].contains(data['feeling'])) {
      return '感受无效';
    }
    if (data['bodyState'] != null &&
        !['无痛', '正常肌肉酸胀', '轻微不适', '明显疼痛'].contains(data['bodyState'])) {
      return '身体状态无效';
    }
    if (data['completed'] is! bool) return '完成状态无效';
    return null;
  }

  String? validate(LoadKind kind) {
    final fieldsError = validateFields();
    if (fieldsError != null) return fieldsError;
    if (kind == LoadKind.cardio) {
      return (seconds ?? 0) > 0 ? null : '请填写大于 0 的时长';
    }
    if (kind == LoadKind.dumbbell) {
      if (weight == null || data['sideMode'] == null) return '请填写单只重量并选择单双侧';
      return ((value('leftReps') ?? 0) + (value('rightReps') ?? 0)) > 0
          ? null
          : '请填写实际左右次数';
    }
    if (kind == LoadKind.external && weight == null) return '请填写总外部重量';
    if (kind == LoadKind.assisted && value('assistance') == null) {
      return '请填写辅助重量';
    }
    return (reps ?? 0) > 0 ? null : '请填写大于 0 的次数';
  }

  double volume(LoadKind kind) {
    if (!completed) return 0;
    return switch (kind) {
      LoadKind.external => (weight ?? 0) * (reps ?? 0),
      LoadKind.dumbbell =>
        (weight ?? 0) * ((value('leftReps') ?? 0) + (value('rightReps') ?? 0)),
      _ => 0,
    };
  }

  WorkoutSet duplicate() => WorkoutSet({
    ...toJson(),
    ...Record.base(),
    'completed': false,
    'completedAt': null,
  });
}

class WorkoutExercise extends Record {
  WorkoutExercise(super.data);
  factory WorkoutExercise.fromExercise(Exercise e) => WorkoutExercise({
    ...Record.base(),
    'exerciseId': e.id,
    'snapshot': e.toJson(),
    'skipped': false,
    'restSeconds': 90,
    'sets': [WorkoutSet.empty().toJson()],
  });
  Exercise get exercise => Exercise(data['snapshot'] as Json);
  bool get skipped => data['skipped'] == true;
  List<WorkoutSet> get sets => (data['sets'] as List)
      .cast<Json>()
      .map(WorkoutSet.new)
      .where((s) => !s.deleted)
      .toList();
}

class Session extends Record {
  Session(super.data);
  factory Session.start(
    String title,
    List<WorkoutExercise> exercises, {
    DateTime? at,
  }) => Session({
    ...Record.base(),
    'title': title,
    'startedAt': (at ?? DateTime.now()).toUtc().toIso8601String(),
    'endedAt': null,
    'pauses': <Json>[],
    'exercises': exercises.map((e) => e.toJson()).toList(),
  });
  String get title => data['title'] as String;
  DateTime get startedAt => DateTime.parse(data['startedAt'] as String);
  DateTime? get endedAt => DateTime.tryParse(data['endedAt'] as String? ?? '');
  bool get active => !deleted && endedAt == null;
  List<WorkoutExercise> get exercises => (data['exercises'] as List)
      .cast<Json>()
      .map(WorkoutExercise.new)
      .where((e) => !e.deleted)
      .toList();
  List<Json> get pauses => (data['pauses'] as List).cast<Json>();
  bool get paused => pauses.any((p) => p['end'] == null);
  Duration duration(DateTime now) {
    final end = endedAt ?? now;
    var ms = end.difference(startedAt).inMilliseconds;
    for (final p in pauses) {
      final start = DateTime.parse(p['start'] as String);
      final pauseEnd = p['end'] == null
          ? end
          : DateTime.parse(p['end'] as String);
      ms -= pauseEnd.difference(start).inMilliseconds;
    }
    return Duration(milliseconds: ms.clamp(0, 1 << 52));
  }

  int get completedSets => exercises.fold(
    0,
    (sum, e) => sum + e.sets.where((s) => s.completed).length,
  );
}

class WorkoutTemplate extends Record {
  WorkoutTemplate(super.data);
  factory WorkoutTemplate.create(
    String name,
    List<WorkoutExercise> exercises,
  ) => WorkoutTemplate({
    ...Record.base(),
    'name': name,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  });
  String get name => data['name'] as String;
  List<WorkoutExercise> freshExercises() =>
      (data['exercises'] as List).cast<Json>().map((raw) {
        final e = WorkoutExercise({
          ...jsonDecode(jsonEncode(raw)) as Json,
          ...Record.base(),
          'skipped': false,
        });
        e.data['sets'] = e.sets.map((s) => s.duplicate().toJson()).toList();
        return e;
      }).toList();
}

class AppData {
  AppData({
    List<Exercise>? exercises,
    List<WorkoutTemplate>? templates,
    List<Session>? sessions,
    List<Record>? measurements,
    Json? settings,
    Json? schedule,
    this.revision = 0,
  }) : exercises = exercises ?? [],
       templates = templates ?? [],
       sessions = sessions ?? [],
       measurements = measurements ?? [],
       settings =
           settings ??
           {
             'brand': 'blue',
             'appearance': 'system',
             'weeklyGoal': 3,
             'nickname': '训练者',
           },
       schedule = schedule ?? {};
  final List<Exercise> exercises;
  final List<WorkoutTemplate> templates;
  final List<Session> sessions;
  final List<Record> measurements;
  final Json settings;
  final Json schedule;
  int revision;
  Session? get active => sessions.where((s) => s.active).firstOrNull;
  Json toJson() => {
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'templates': templates.map((t) => t.toJson()).toList(),
    'sessions': sessions.map((s) => s.toJson()).toList(),
    'measurements': measurements.map((m) => m.toJson()).toList(),
    'settings': settings,
    'schedule': schedule,
    'revision': revision,
  };
  factory AppData.fromJson(Json j) => AppData(
    exercises: (j['exercises'] as List).cast<Json>().map(Exercise.new).toList(),
    templates: (j['templates'] as List)
        .cast<Json>()
        .map(WorkoutTemplate.new)
        .toList(),
    sessions: (j['sessions'] as List).cast<Json>().map(Session.new).toList(),
    measurements: (j['measurements'] as List)
        .cast<Json>()
        .map(Record.new)
        .toList(),
    settings: j['settings'] as Json,
    schedule: j['schedule'] as Json,
    revision: (j['revision'] as num?)?.toInt() ?? 0,
  );
  AppData copy() => AppData.fromJson(jsonDecode(jsonEncode(toJson())) as Json);
}

AppData initialData() {
  final catalog = <Exercise>[];
  void add(String name, String muscle, String equipment, LoadKind kind) =>
      catalog.add(Exercise.create(name, muscle, equipment, kind));
  add('杠铃卧推', '胸', '杠铃', LoadKind.external);
  add('哑铃卧推', '胸', '哑铃', LoadKind.dumbbell);
  add('高位下拉', '背', '器械', LoadKind.external);
  add('坐姿划船', '背', '器械', LoadKind.external);
  add('辅助引体向上', '背', '辅助器械', LoadKind.assisted);
  add('哑铃推举', '肩', '哑铃', LoadKind.dumbbell);
  add('哑铃侧平举', '肩', '哑铃', LoadKind.dumbbell);
  add('哑铃弯举', '手臂', '哑铃', LoadKind.dumbbell);
  add('绳索下压', '手臂', '器械', LoadKind.external);
  add('杠铃深蹲', '腿', '杠铃', LoadKind.external);
  add('腿举', '腿', '器械', LoadKind.external);
  add('跑步机', '全身', '有氧器械', LoadKind.cardio);
  add('健身车', '全身', '有氧器械', LoadKind.cardio);
  final templates = ['胸', '背', '肩', '手臂', '腿', '全身'].map((m) {
    final selected = catalog
        .where(
          (e) => m == '全身'
              ? ['杠铃深蹲', '杠铃卧推', '坐姿划船'].contains(e.name)
              : e.muscle == m,
        )
        .take(3);
    return WorkoutTemplate.create(
      '$m · 示例',
      selected.map((e) {
        final move = WorkoutExercise.fromExercise(e);
        move.data['sets'] = List.generate(
          3,
          (_) => WorkoutSet.empty().toJson(),
        );
        return move;
      }).toList(),
    );
  }).toList();
  // Catalog/templates only. No workouts or body measurements are seeded.
  return AppData(exercises: catalog, templates: templates);
}
