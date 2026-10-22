import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/ui/active_workout.dart';
import 'package:lianji/ui/body.dart';
import 'package:lianji/ui/backup_page.dart';
import 'package:lianji/ui/components.dart';
import 'package:lianji/ui/history.dart';
import 'package:lianji/ui/home.dart';
import 'package:lianji/ui/library.dart';
import 'package:lianji/ui/profile.dart';
import 'package:lianji/ui/statistics_page.dart';
import 'package:lianji/ui/templates.dart';
import 'package:lianji/ui/theme.dart';
import 'statistics_presentation_test.dart' show statisticsFixture;

// Explicit capture suite. Test-only fixture never enters the production DB.
void main() {
  const capture = bool.fromEnvironment('CAPTURE_VISUALS');
  testWidgets('六套主题主要页面截图与各页布局检查', (tester) async {
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadows);
    tester.view.physicalSize = const Size(432, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = File('C:/Windows/Fonts/msyh.ttc');
    if (font.existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }
    final icons = File(
      '.tooling/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await iconLoader.load();
    final d = initialData();
    final statData = statisticsFixture();
    final session = Session.start('胸 · 力量记录', [
      WorkoutExercise.fromExercise(d.exercises.first),
    ]);
    d.sessions.add(session);
    session.exercises.first.sets.first.data.addAll({'weight': 40, 'reps': 8});
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final past = Session.start('背 · 测试夹具', [
      WorkoutExercise.fromExercise(d.exercises[2]),
    ], at: yesterday);
    past.data['endedAt'] = yesterday
        .add(const Duration(minutes: 45))
        .toUtc()
        .toIso8601String();
    past.exercises.first.sets.first.data.addAll({
      'weight': 35,
      'reps': 10,
      'completed': true,
      'completedAt': yesterday
          .add(const Duration(minutes: 10))
          .toUtc()
          .toIso8601String(),
    });
    d.sessions.add(past);
    d.measurements.add(
      Record({...Record.base(), 'date': dateKey(yesterday), 'weight': 65.5}),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    final screens = <String, Widget>{
      'home': const HomePage(),
      'active': const ActiveWorkoutPage(),
      'appearance': const AppearancePage(),
      'train': const TrainPage(),
      'library': const LibraryPage(),
      'templates': const TemplatesPage(),
      'schedule': const SchedulePage(),
      'history': const HistoryPage(),
      'statistics': const StatisticsPage(),
      'statistics-trend': const StatisticsPage(),
      'body': const BodyPage(),
      'profile': const ProfilePage(),
      'backup': const BackupPage(),
      'backup-actions': const BackupPage(),
      'template-editor': TemplateEditor(id: d.templates.first.id),
      'history-detail': ActiveWorkoutPage(sessionId: past.id),
    };
    Directory('artifacts/screenshots').createSync(recursive: true);
    for (final brand in BrandTheme.values) {
      for (final brightness in Brightness.values) {
        d.settings['brand'] = brand.name;
        d.settings['appearance'] = brightness.name;
        statData.settings['brand'] = brand.name;
        statData.settings['appearance'] = brightness.name;
        final keys = screens.keys;
        for (final name in keys) {
          final pageData = name.startsWith('statistics') ? statData : d;
          final boundary = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                controllerProvider.overrideWith(
                  (ref) => AppController(
                    MemoryTrainingRepository(pageData),
                    pageData,
                  ),
                ),
              ],
              child: MaterialApp(
                locale: const Locale('zh', 'CN'),
                supportedLocales: const [Locale('zh', 'CN')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: AppTheme.build(brand, brightness),
                home: RepaintBoundary(
                  key: boundary,
                  child: AppScaffold(
                    location:
                        [
                          'active',
                          'train',
                          'library',
                          'templates',
                          'template-editor',
                          'schedule',
                        ].contains(name)
                        ? '/train'
                        : [
                            'appearance',
                            'body',
                            'backup',
                            'backup-actions',
                            'profile',
                          ].contains(name)
                        ? '/profile'
                        : name.startsWith('statistics')
                        ? '/stats'
                        : '/',
                    child: screens[name]!,
                  ),
                ),
              ),
            ),
          );
          if (name == 'home') {
            await tester.runAsync(
              () => precacheImage(
                const AssetImage('assets/images/home-hero-jade.png'),
                tester.element(find.byType(HomePage)),
              ),
            );
          }
          await tester.pumpAndSettle();
          if (name == 'backup-actions') {
            await tester.ensureVisible(
              find.byKey(const ValueKey('webdav-actions')),
            );
            await tester.pumpAndSettle();
          }
          if (name == 'statistics-trend') {
            await tester.tap(find.text('动作趋势'));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('stats-exercise')));
            await tester.pumpAndSettle();
            await tester.tap(find.text('杠铃卧推 · 外部负重').last);
            await tester.pumpAndSettle();
            final vertical = tester.state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(CustomScrollView).first,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            vertical.position.jumpTo(0);
            await tester.pumpAndSettle();
          }
          expect(
            tester.takeException(),
            null,
            reason: '$brand $brightness $name',
          );
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final img = await render.toImage(pixelRatio: 1);
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            await File(
              'artifacts/screenshots/${brand.name}-${brightness.name}-$name.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      }
    }
    for (final size in [
      const Size(347, 780),
      const Size(360, 780),
      const Size(900, 600),
      const Size(1280, 900),
    ]) {
      tester.view.physicalSize = size;
      for (final screen in screens.values) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              controllerProvider.overrideWith(
                (ref) => AppController(MemoryTrainingRepository(d), d),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.build(BrandTheme.orange, Brightness.light),
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: AppScaffold(location: '/', child: screen),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), null, reason: '$size $screen 200%');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    }
    debugDisableShadows = previousShadows;
  }, skip: !capture);
}
