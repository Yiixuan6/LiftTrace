import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/backup.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/l10n/app_strings.dart';
import 'package:lianji/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppStrings.prepare);
  test(
    'locale negotiation covers Chinese scripts and regions, English and fallback',
    () {
      expect(
        AppStrings.resolve(const Locale('zh', 'TW')),
        AppStrings.traditional,
      );
      expect(
        AppStrings.resolve(const Locale('zh', 'HK')),
        AppStrings.traditional,
      );
      expect(
        AppStrings.resolve(const Locale('zh', 'MO')),
        AppStrings.traditional,
      );
      expect(
        AppStrings.resolve(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ),
        AppStrings.traditional,
      );
      expect(
        AppStrings.resolve(const Locale('zh', 'SG')),
        AppStrings.simplified,
      );
      expect(AppStrings.resolve(const Locale('en', 'GB')), AppStrings.english);
      expect(AppStrings.resolve(const Locale('fr')), AppStrings.simplified);
    },
  );

  test(
    'all translated catalogs have matching keys and placeholders; arguments are not translated',
    () async {
      final en = await AppStrings.load(AppStrings.english);
      final hant = await AppStrings.load(AppStrings.traditional);
      expect(en.messages.keys.toSet(), hant.messages.keys.toSet());
      final pattern = RegExp(r'\{\d+\}');
      for (final catalog in [en, hant]) {
        for (final entry in catalog.messages.entries) {
          expect(entry.value.isNotEmpty, isTrue, reason: entry.key);
          expect(
            pattern.allMatches(entry.value).map((m) => m[0]).toSet(),
            pattern.allMatches(entry.key).map((m) => m[0]).toSet(),
            reason: entry.key,
          );
        }
        expect(catalog.text('完成下一组 · {0}', ['训练 {1}']), contains('训练 {1}'));
      }
      expect(hant.text('训练历史'), '訓練歷史');
      expect(en.text('休息结束'), 'Rest complete');
      expect(en.error('WebDAV 请求失败（401）'), 'WebDAV request failed (401)');
    },
  );

  test(
    'language and existing rest presets round trip without changing training data; old backups still work',
    () async {
      final data = initialData();
      final session = Session.start('我的训练 · My session {0}', [
        WorkoutExercise.fromExercise(data.exercises.first),
      ]);
      session.exercises.first.sets.first.data.addAll({
        'weight': 40,
        'reps': 8,
        'note': '保留我的备注',
      });
      data.sessions.add(session);
      final records = jsonEncode(data.sessions.map((s) => s.toJson()).toList());
      for (final code in AppStrings.preferences) {
        data.settings['language'] = code;
        data.settings['restPresetSeconds'] = 120;
        final restored = BackupCodec.decode(BackupCodec.encode(data));
        expect(restored.settings['language'], code);
        expect(restored.settings['restPresetSeconds'], 120);
        expect(
          jsonEncode(restored.sessions.map((s) => s.toJson()).toList()),
          records,
        );
      }
      data.settings.remove('language');
      expect(
        BackupCodec.decode(
          BackupCodec.encode(data),
        ).settings.containsKey('language'),
        isFalse,
      );
      data.settings['language'] = 'unsupported';
      expect(
        () => BackupCodec.decode(BackupCodec.encode(data)),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'language picker persists and preserves active input, rest, records and navigation',
    (tester) async {
      tester.view.physicalSize = const Size(432, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = initialData();
      final session = Session.start('自定义训练 Workout', [
        WorkoutExercise.fromExercise(data.exercises.first),
      ]);
      session.exercises.first.sets.first.data.addAll({
        'weight': 40,
        'reps': 8,
        'note': '我的原始备注',
      });
      data.sessions.add(session);
      data.settings['restRemaining'] = 120;
      final repository = MemoryTrainingRepository(data);
      final controller = AppController(repository, data);
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
      await tester.pumpAndSettle();
      final records = jsonEncode(
        controller.data.sessions.map((s) => s.toJson()).toList(),
      );
      appRouter.go('/profile');
      await tester.pumpAndSettle();
      final picker = find.byKey(const ValueKey('language-settings'));
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-en')));
      await tester.pumpAndSettle();
      expect(
        find.text('Language'),
        findsOneWidget,
        reason:
            'locale=${tester.widget<MaterialApp>(find.byType(MaterialApp)).locale} texts=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
      );
      expect((await repository.load()).settings['language'], 'en');
      appRouter.go('/train/active');
      await tester.pumpAndSettle();
      expect(find.text('Total external weight (kg)'), findsOneWidget);
      expect(tester.widget<TextField>(weight).controller!.text, '37.5');
      expect(controller.data.settings['restRemaining'], 120);
      expect(
        jsonEncode(controller.data.sessions.map((s) => s.toJson()).toList()),
        records,
      );
      expect(find.text('自定义训练 Workout'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('system language updates live while explicit choice stays fixed', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final data = initialData();
    data.settings['language'] = 'system';
    final controller = AppController(MemoryTrainingRepository(data), data);
    appRouter.go('/profile');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [controllerProvider.overrideWith((ref) => controller)],
        child: const LianjiApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Language'),
      findsOneWidget,
      reason:
          'locale=${tester.widget<MaterialApp>(find.byType(MaterialApp)).locale} texts=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
    );
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'TW')];
    await tester.pumpAndSettle();
    expect(
      find.text('語言'),
      findsOneWidget,
      reason:
          '${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
    );
    await controller.change((d) => d.settings['language'] = 'en');
    await tester.pumpAndSettle();
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    await tester.pumpAndSettle();
    expect(
      find.text('Language'),
      findsOneWidget,
      reason:
          'locale=${tester.widget<MaterialApp>(find.byType(MaterialApp)).locale} texts=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
