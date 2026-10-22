import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/backup.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/l10n/app_strings.dart';
import 'package:lianji/main.dart';
import 'package:lianji/ui/liquid_glass.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('isolated Android three-language persistence and active input', (
    tester,
  ) async {
    const info = MethodChannel('app.lianji.training/app-info');
    expect(
      await info.invokeMethod<String>('getApplicationName'),
      '练迹设计验收',
      reason: 'Only the isolated design package may run this fixture',
    );
    await AppStrings.prepare();
    await LiquidGlassSurface.prepare();
    final temp = await getTemporaryDirectory();
    final databasePath = '${temp.path}/localization-${newId()}.db';
    final repo = await SqliteTrainingRepository.open(path: databasePath);
    final data = await repo.load();
    final session = Session.start('多语言演示 · My workout {1}', [
      WorkoutExercise.fromExercise(data.exercises.first),
    ]);
    session.exercises.first.sets.first.data.addAll({
      'weight': 40,
      'reps': 8,
      'note': '原始备注 · Keep this note',
    });
    data.sessions.add(session);
    data.settings['restRemaining'] = 120;
    await repo.save(data);
    final controller = AppController(repo, data);
    appRouter.go('/train/active');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [controllerProvider.overrideWith((ref) => controller)],
        child: const LianjiApp(),
      ),
    );
    await tester.pumpAndSettle();
    final weight = find.byKey(const ValueKey('input-总外部重量 kg'));
    await tester.ensureVisible(weight);
    await tester.enterText(weight, '37.5');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final records = jsonEncode(
      controller.data.sessions.map((s) => s.toJson()).toList(),
    );
    for (final language in ['en', 'zh_Hant', 'zh_Hans']) {
      appRouter.go('/profile');
      await tester.pumpAndSettle();
      final picker = find.byKey(const ValueKey('language-settings'));
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('language-$language')));
      await tester.pumpAndSettle();
      expect((await repo.load()).settings['language'], language);
      final expected = switch (language) {
        'en' => 'Language',
        'zh_Hant' => '語言',
        _ => '语言',
      };
      expect(find.text(expected), findsOneWidget);
      appRouter.go('/train/active');
      await tester.pumpAndSettle();
      await tester.ensureVisible(weight);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(weight).controller!.text, '37.5');
      expect(controller.data.settings['restRemaining'], 120);
      expect(
        jsonEncode(controller.data.sessions.map((s) => s.toJson()).toList()),
        records,
      );
      expect(
        BackupCodec.decode(
          BackupCodec.encode(controller.data),
        ).settings['language'],
        language,
      );
    }
    await controller.change((d) => d.settings['language'] = 'zh_Hant');
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await repo.close();
    final reopened = await SqliteTrainingRepository.open(path: databasePath);
    final restored = await reopened.load();
    expect(restored.settings['language'], 'zh_Hant');
    expect(
      jsonEncode(restored.sessions.map((s) => s.toJson()).toList()),
      records,
    );
    await reopened.close();
    debugPrint(
      'LOCALIZATION_NATIVE_PASSED=true THREE_LANGUAGES=true SQLITE_REOPEN=true USER_DATA_READ=false',
    );
  });
}
