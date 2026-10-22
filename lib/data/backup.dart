import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../domain/models.dart';

class BackupCodec {
  static const version = 1;
  static const maxBytes = 50 * 1024 * 1024;
  static String encode(AppData data) {
    final portable = data.copy();
    portable.settings.remove('restDeadline');
    portable.settings.remove('restRemaining');
    final payload = jsonEncode(portable.toJson());
    return jsonEncode({
      'format': 'lianji.full',
      'version': version,
      'exportedAt': stamp(),
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
      'payload': payload,
    });
  }

  static AppData decode(String source) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('备份超过 50 MB 限制');
    }
    final envelope = jsonDecode(source);
    if (envelope is! Json ||
        envelope['format'] != 'lianji.full' ||
        envelope['version'] != version) {
      throw const FormatException('不支持的备份格式或版本；原数据未修改');
    }
    final payload = envelope['payload'];
    if (payload is! String ||
        sha256.convert(utf8.encode(payload)).toString() != envelope['sha256']) {
      throw const FormatException('备份校验失败；原数据未修改');
    }
    try {
      final data = AppData.fromJson(jsonDecode(payload) as Json);
      validate(data);
      return data;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('备份结构无效；原数据未修改');
    }
  }

  static void validate(AppData data) {
    if (data.settings.containsKey('language') &&
        ![
          'system',
          'zh_Hans',
          'zh_Hant',
          'en',
        ].contains(data.settings['language'])) {
      throw const FormatException('不支持的语言设置');
    }
    final preset = data.settings['restPresetSeconds'];
    if (preset != null && (preset is! int || preset < 1 || preset > 86400)) {
      throw const FormatException('休息时长无效');
    }
    if (data.revision < 0) throw const FormatException('修订号无效');
    const settingKeys = {
      'brand',
      'appearance',
      'weeklyGoal',
      'nickname',
      'autoBackup',
      'restDeadline',
      'restRemaining',
      'language',
      'restPresetSeconds',
    };
    if (data.settings.keys.any((key) => !settingKeys.contains(key))) {
      throw const FormatException('设置包含未知或设备专用字段');
    }
    if (data.sessions.where((s) => s.active).length > 1) {
      throw const FormatException('备份包含多个进行中训练');
    }
    final ids = <String>{};
    void record(Record r) {
      if (r.id.isEmpty || !ids.add(r.id)) {
        throw const FormatException('ID 缺失或重复');
      }
      for (final key in ['createdAt', 'updatedAt']) {
        DateTime.parse(r.data[key] as String);
      }
      if (r.data['deleted'] is! bool) throw const FormatException('删除状态无效');
    }

    for (final e in data.exercises) {
      record(e);
      if (e.name.trim().isEmpty) throw const FormatException('动作名称为空');
      e.kind;
      e.muscle;
      e.equipment;
    }
    void move(WorkoutExercise e) {
      record(e);
      if (e.data['exerciseId'] is! String || e.data['skipped'] is! bool) {
        throw const FormatException('训练动作结构无效');
      }
      final snapshot = e.exercise;
      snapshot.kind;
      snapshot.name;
      snapshot.muscle;
      snapshot.equipment;
      final rest = e.data['restSeconds'];
      if (rest is! num ||
          rest != rest.roundToDouble() ||
          rest <= 0 ||
          rest > 86400) {
        throw const FormatException('休息时长无效');
      }
      for (final raw in (e.data['sets'] as List).cast<Json>()) {
        final set = WorkoutSet(raw);
        record(set);
        if (set.validateFields() != null) {
          throw const FormatException('组数据字段无效');
        }
        if (set.completed &&
            (set.validate(snapshot.kind) != null ||
                DateTime.tryParse(set.data['completedAt'] as String? ?? '') ==
                    null)) {
          throw const FormatException('已完成组缺少有效数据或完成时间');
        }
      }
    }

    for (final t in data.templates) {
      record(t);
      t.name;
      for (final raw in (t.data['exercises'] as List).cast<Json>()) {
        move(WorkoutExercise(raw));
      }
    }
    for (final s in data.sessions) {
      record(s);
      s.title;
      if (s.data['endedAt'] != null) {
        DateTime.parse(s.data['endedAt'] as String);
      }
      if (s.endedAt != null && s.endedAt!.isBefore(s.startedAt)) {
        throw const FormatException('训练结束早于开始');
      }
      DateTime? lastPauseEnd;
      var openPause = false;
      for (final p in s.pauses) {
        final start = DateTime.parse(p['start'] as String);
        final end = p['end'] == null
            ? null
            : DateTime.parse(p['end'] as String);
        if (openPause ||
            start.isBefore(s.startedAt) ||
            (lastPauseEnd != null && start.isBefore(lastPauseEnd)) ||
            (end != null && end.isBefore(start)) ||
            (s.endedAt != null && (end == null || end.isAfter(s.endedAt!)))) {
          throw const FormatException('暂停区间无效');
        }
        openPause = end == null;
        lastPauseEnd = end;
      }
      for (final raw in (s.data['exercises'] as List).cast<Json>()) {
        move(WorkoutExercise(raw));
      }
    }
    final measurementDates = <String>{};
    for (final m in data.measurements) {
      record(m);
      if (!m.deleted && !measurementDates.add(m.data['date'] as String)) {
        throw const FormatException('同一天有重复身体记录');
      }
      if (dateKey(DateTime.parse(m.data['date'] as String)) != m.data['date']) {
        throw const FormatException('身体记录日期无效');
      }
      for (final key in ['weight', 'waist', 'chest', 'hips', 'arm', 'thigh']) {
        final n = m.data[key];
        if (n != null && (n is! num || !n.isFinite || n <= 0)) {
          throw const FormatException('身体数据无效');
        }
      }
    }
    BrandTheme.values.byName(data.settings['brand'] as String);
    Appearance.values.byName(data.settings['appearance'] as String);
    final goal = data.settings['weeklyGoal'];
    if (data.settings['nickname'] is! String ||
        goal is! int ||
        goal < 1 ||
        goal > 21 ||
        (data.settings['autoBackup'] != null &&
            data.settings['autoBackup'] is! bool)) {
      throw const FormatException('设置字段无效');
    }
    for (final entry in data.schedule.entries) {
      if (!['1', '2', '3', '4', '5', '6', '7'].contains(entry.key) ||
          (entry.value != 'rest' &&
              !data.templates.any((t) => !t.deleted && t.id == entry.value))) {
        throw const FormatException('周安排引用无效');
      }
    }
    if (data.settings.keys.any(
      (k) =>
          k.toLowerCase().contains('password') ||
          k.toLowerCase().contains('secret'),
    )) {
      throw const FormatException('备份不允许包含凭据');
    }
  }

  static String csv(AppData data) {
    String cell(Object? v) {
      var text = (v ?? '').toString();
      if (v is String && RegExp(r'^\s*[=+@-]').hasMatch(text)) text = "'$text";
      return '"${text.replaceAll('"', '""')}"';
    }

    final rows = <List<Object?>>[
      [
        '训练ID',
        '开始UTC',
        '动作',
        '类型',
        '单只或总重量kg',
        '次数',
        '左次数',
        '右次数',
        '辅助kg',
        '有氧秒',
        '距离km',
        '感受',
        '身体状态',
        '备注',
      ],
    ];
    for (final s in data.sessions.where((s) => !s.deleted)) {
      for (final e in s.exercises) {
        for (final set in e.sets.where((s) => s.completed)) {
          rows.add([
            s.id,
            s.data['startedAt'],
            e.exercise.name,
            e.exercise.kind.name,
            ...[
              'weight',
              'reps',
              'leftReps',
              'rightReps',
              'assistance',
              'seconds',
              'distance',
              'feeling',
              'bodyState',
              'note',
            ].map((k) => set.data[k]),
          ]);
        }
      }
    }
    return '\uFEFF${rows.map((r) => r.map(cell).join(',')).join('\r\n')}';
  }
}
