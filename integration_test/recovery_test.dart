import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/backup.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/platform/reminders.dart';

// Run seed, force-stop only app.lianji.training.qa, then run resume.
// This entry point must only be installed with LIANJI_TEST_BUILD=1.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('QA_PHASE', defaultValue: 'seed');
  testWidgets('Android isolated recovery $phase', (tester) async {
    final directory = await getApplicationSupportDirectory();
    expect(directory.path, contains('app.lianji.training.qa'));
    final marker = File('${directory.path}/recovery-expected.json');
    final path = '${directory.path}/recovery-qa.db';
    const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
    );
    final repo = await SqliteTrainingRepository.open(path: path);
    final controller = AppController(repo, await repo.load());
    if (phase == 'seed') {
      expect(
        await marker.exists(),
        isFalse,
        reason: 'Refuse to overwrite an existing recovery fixture',
      );
      final id = await controller.start();
      await controller.addExercise(id, controller.data.exercises.first);
      final exercise = controller.data.active!.exercises.single;
      final set = exercise.sets.first;
      await controller.editSet(id, exercise.id, set.id, {
        'weight': 42,
        'reps': 9,
      });
      await controller.completeSet(id, exercise.id, set.id);
      await controller.updateSession(id, (session) {
        final draft = WorkoutSet.empty();
        draft.data['weight'] = 12;
        (session.exercises.single.data['sets'] as List).add(draft.toJson());
      });
      await controller.pause(id);
      await controller.change((data) {
        data.settings['brand'] = 'blue';
        data.settings['appearance'] = 'dark';
      });
      await marker.writeAsString(
        BackupCodec.encode(controller.data),
        flush: true,
      );
      // Non-secret test fixture, removed during resume; no user credentials.
      await secure.write(key: 'qa-recovery-probe', value: id);
      final reminders = RestReminders();
      await reminders.initialize();
      await reminders.schedule(DateTime.now().add(const Duration(hours: 1)));
      expect(
        await reminders.plugin.pendingNotificationRequests(),
        hasLength(1),
      );
      await reminders.cancel();
      expect(await reminders.plugin.pendingNotificationRequests(), isEmpty);
      // Leave SQLite open so the external force-stop crosses a process boundary.
    } else {
      expect(phase, 'resume');
      final expected = BackupCodec.decode(await marker.readAsString());
      expect(controller.data.toJson(), expected.toJson());
      final active = controller.data.active!;
      expect(active.paused, isTrue);
      expect(active.completedSets, 1);
      expect(active.exercises.single.sets.first.weight, 42);
      expect(active.exercises.single.sets.last.completed, isFalse);
      expect(active.exercises.single.sets.last.weight, 12);
      expect(active.exercises.single.sets.last.reps, isNull);
      expect(await secure.read(key: 'qa-recovery-probe'), active.id);
      await secure.delete(key: 'qa-recovery-probe');
      await controller.pause(active.id);
      await controller.finish(active.id);
      expect(controller.data.active, isNull);
      await repo.close();
      final reopened = await SqliteTrainingRepository.open(path: path);
      expect((await reopened.load()).sessions.single.completedSets, 1);
      await reopened.close();
    }
  });
}
