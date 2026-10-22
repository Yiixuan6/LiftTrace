import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lianji/data/backup.dart';
import 'package:lianji/data/repository.dart';

// Read the 0.1.0 QA fixture kept by the prior, successful recovery acceptance.
// Never use the production application ID or its database.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('0.1.0到0.2.0同证书QA覆盖保留原记录', (tester) async {
    final directory = await getApplicationSupportDirectory();
    expect(directory.path, contains('app.lianji.training.qa'));
    final marker = File('${directory.path}/recovery-expected.json');
    expect(
      await marker.exists(),
      isTrue,
      reason: 'Requires the preserved 0.1.0 QA fixture; never fabricate it',
    );
    final previous = BackupCodec.decode(await marker.readAsString());
    final repo = await SqliteTrainingRepository.open(
      path: '${directory.path}/recovery-qa.db',
    );
    final current = await repo.load();
    final original = previous.sessions.single;
    final restored = current.sessions.single;
    expect(restored.id, original.id);
    expect(restored.data['createdAt'], original.data['createdAt']);
    expect(restored.startedAt, original.startedAt);
    expect(restored.active, isFalse);
    expect(restored.completedSets, 1);
    expect(
      restored.exercises.map((e) => e.toJson()).toList(),
      original.exercises.map((e) => e.toJson()).toList(),
    );
    expect(current.settings, previous.settings);
    expect(restored.exercises.single.sets.first.weight, 42);
    expect(restored.exercises.single.sets.last.weight, 12);
    expect(restored.exercises.single.sets.last.completed, isFalse);
    expect(
      (await repo.database.rawQuery(
        'PRAGMA user_version',
      )).single.values.single,
      1,
    );
    await repo.close();
  });
}
