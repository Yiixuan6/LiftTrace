import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/l10n/app_strings.dart';
import 'package:lianji/ui/active_workout.dart';
import 'package:lianji/ui/backup_page.dart';
import 'package:lianji/ui/body.dart';
import 'package:lianji/ui/components.dart';
import 'package:lianji/ui/history.dart';
import 'package:lianji/ui/home.dart';
import 'package:lianji/ui/library.dart';
import 'package:lianji/ui/profile.dart';
import 'package:lianji/ui/statistics_page.dart';
import 'package:lianji/ui/templates.dart';
import 'package:lianji/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppStrings.prepare);
  testWidgets('three languages across all pages, 347dp/200%, and six appearances', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(347, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final spec in [
      ('Roboto', 'C:/Windows/Fonts/msyh.ttc'),
      (
        'MaterialIcons',
        '.tooling/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    ]) {
      final f = File(spec.$2);
      if (f.existsSync()) {
        await (FontLoader(
              spec.$1,
            )..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync()))))
            .load();
      }
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    final data = initialData();
    final active = Session.start('力量练习 · Demo', [
      WorkoutExercise.fromExercise(data.exercises.first),
    ]);
    active.exercises.first.sets.first.data.addAll({'weight': 40, 'reps': 8});
    data.sessions.add(active);
    final past = Session.start('背部记录 · Demo', [
      WorkoutExercise.fromExercise(data.exercises[2]),
    ], at: DateTime.now().subtract(const Duration(days: 1)));
    past.data['endedAt'] = DateTime.now()
        .subtract(const Duration(hours: 20))
        .toUtc()
        .toIso8601String();
    past.exercises.first.sets.first.data.addAll({
      'weight': 35,
      'reps': 10,
      'completed': true,
      'completedAt': past.data['endedAt'],
    });
    data.sessions.add(past);
    data.measurements.add(
      Record({
        ...Record.base(),
        'date': dateKey(DateTime.now()),
        'weight': 65.5,
      }),
    );
    final screens = <String, Widget>{
      'home': const HomePage(),
      'training': const TrainPage(),
      'profile': const ProfilePage(),
      'statistics': const StatisticsPage(),
      'active': const ActiveWorkoutPage(),
      'library': const LibraryPage(),
      'templates': const TemplatesPage(),
      'schedule': const SchedulePage(),
      'history': const HistoryPage(),
      'body': const BodyPage(),
      'backup': const BackupPage(),
      'appearance': const AppearancePage(),
      'template-editor': TemplateEditor(id: data.templates.first.id),
      'history-detail': ActiveWorkoutPage(sessionId: past.id),
    };
    var checked = 0, captured = 0;
    const capture = bool.fromEnvironment('CAPTURE_LOCALIZATION');
    for (final language in ['zh_Hans', 'zh_Hant', 'en']) {
      for (final scale in [1.0, 2.0]) {
        for (final entry in screens.entries) {
          final copy = data.copy();
          copy.settings.addAll({
            'language': language,
            'brand': 'blue',
            'appearance': 'light',
          });
          final controller = AppController(
            MemoryTrainingRepository(copy),
            copy,
          );
          final boundary = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [controllerProvider.overrideWith((ref) => controller)],
              child: MaterialApp(
                locale: AppStrings.preferred(language),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: const [
                  AppStrings.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                theme: AppTheme.build(BrandTheme.blue, Brightness.light),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(347, 780),
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: RepaintBoundary(
                    key: boundary,
                    child: AppScaffold(location: '/', child: entry.value),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$language $scale ${entry.key}',
          );
          checked++;
          if (capture &&
              scale == 1 &&
              [
                'home',
                'training',
                'profile',
                'statistics',
                'active',
                'backup',
                'schedule',
                'template-editor',
              ].contains(entry.key)) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = Directory(
                'artifacts/localization-0.2.11/screenshots',
              )..createSync(recursive: true);
              File(
                '${directory.path}/$language-${entry.key}.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
            captured++;
          }
        }
      }
      for (final brand in BrandTheme.values) {
        for (final brightness in Brightness.values) {
          for (final page in ['profile', 'active', 'backup', 'statistics']) {
            final copy = data.copy();
            copy.settings.addAll({
              'language': language,
              'brand': brand.name,
              'appearance': brightness.name,
            });
            await tester.pumpWidget(
              ProviderScope(
                key: UniqueKey(),
                overrides: [
                  controllerProvider.overrideWith(
                    (ref) =>
                        AppController(MemoryTrainingRepository(copy), copy),
                  ),
                ],
                child: MaterialApp(
                  locale: AppStrings.preferred(language),
                  supportedLocales: AppStrings.supportedLocales,
                  localizationsDelegates: const [
                    AppStrings.delegate,
                    ...GlobalMaterialLocalizations.delegates,
                  ],
                  theme: AppTheme.build(brand, brightness),
                  home: AppScaffold(location: '/', child: screens[page]!),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$language ${brand.name} ${brightness.name} $page',
            );
            checked++;
          }
        }
      }
    }
    debugPrint(
      'LOCALIZATION_LAYOUTS=$checked SYNTHETIC_SCREENSHOTS=$captured REAL_DATABASE_READ=false',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
