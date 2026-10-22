import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/backup.dart';
import '../data/repository.dart';
import '../domain/models.dart';

final controllerProvider = ChangeNotifierProvider<AppController>(
  (ref) => throw StateError('必须注入真实仓储'),
);

class AppController extends ChangeNotifier {
  AppController(this.repository, this.data);
  final TrainingRepository repository;
  AppData data;
  Future<void> _tail = Future.value();
  String? error;
  Future<void> Function()? onChanged;
  Future<void> change(void Function(AppData) update) {
    final next = _tail.then((_) async {
      final copy = data.copy();
      update(copy);
      copy.revision++;
      await repository.save(copy);
      data = copy;
      error = null;
      notifyListeners();
      if (onChanged != null) unawaited(onChanged!().catchError((Object _) {}));
    });
    _tail = next.catchError((Object e) {
      error = '保存失败，原数据保留。请重试。';
      notifyListeners();
    });
    return next;
  }

  Future<String> start({WorkoutTemplate? template}) async {
    String? id;
    await change((d) {
      if (d.active != null) {
        id = d.active!.id;
        return;
      }
      final s = Session.start(
        template?.name ?? '自由训练',
        template?.freshExercises() ?? [],
      );
      d.sessions.add(s);
      id = s.id;
    });
    return id!;
  }

  Future<void> updateSession(String id, void Function(Session) edit) =>
      change((d) {
        final s = d.sessions.firstWhere((s) => s.id == id && !s.deleted);
        edit(s);
        s.touch();
      });
  Future<void> addExercise(String id, Exercise exercise) =>
      updateSession(id, (s) {
        (s.data['exercises'] as List).add(
          WorkoutExercise.fromExercise(exercise).toJson(),
        );
      });
  Future<void> editSet(
    String sessionId,
    String exerciseId,
    String setId,
    Json values,
  ) => updateSession(sessionId, (s) {
    final e = s.exercises.firstWhere((e) => e.id == exerciseId);
    final set = e.sets.firstWhere((set) => set.id == setId);
    set.data.addAll(values);
    final fieldsError = set.validateFields();
    if (fieldsError != null) throw FormatException(fieldsError);
    set.touch();
    if (set.completed) {
      final message = set.validate(e.exercise.kind);
      if (message != null) throw FormatException(message);
    }
  });
  Future<void> completeSet(String sessionId, String exerciseId, String setId) =>
      updateSession(sessionId, (s) {
        if (s.active && s.paused) throw const FormatException('请先继续训练');
        final e = s.exercises.firstWhere((e) => e.id == exerciseId);
        final set = e.sets.firstWhere((set) => set.id == setId);
        if (set.completed) return;
        final message = set.validate(e.exercise.kind);
        if (message != null) throw FormatException(message);
        set.data.addAll({
          'completed': true,
          'completedAt': s.active ? stamp() : s.data['endedAt'],
        });
        set.touch();
      });
  Future<void> pause(String id) => updateSession(id, (s) {
    if (!s.active) return;
    if (s.paused) {
      s.pauses.last['end'] = stamp();
    } else {
      s.pauses.add({'start': stamp(), 'end': null});
    }
  });
  Future<void> finish(String id, {String? feeling, String? note}) =>
      updateSession(id, (s) {
        if (!s.active) return;
        final now = stamp();
        if (s.paused) s.pauses.last['end'] = now;
        s.data.addAll({
          'endedAt': now,
          'feeling': feeling,
          'recoveryNote': note,
        });
      });
  Future<void> restore(String source, Directory backupDirectory) async {
    final incoming = BackupCodec.decode(source);
    // Serialize against all edits; backup the exact state being replaced.
    final next = _tail.then((_) async {
      await backupDirectory.create(recursive: true);
      final file = File(
        '${backupDirectory.path}/before-restore-${DateTime.now().microsecondsSinceEpoch}.json',
      );
      await file.writeAsString(BackupCodec.encode(data), flush: true);
      incoming.settings.remove('restDeadline');
      incoming.settings.remove('restRemaining');
      incoming.settings['autoBackup'] = false;
      incoming.revision = data.revision + 1;
      await repository.save(incoming);
      data = incoming;
      notifyListeners();
    });
    _tail = next.catchError((Object _) {});
    return next;
  }
}
