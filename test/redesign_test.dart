import 'dart:io';
import 'dart:convert';
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
import 'package:lianji/main.dart';
import 'package:lianji/ui/components.dart';
import 'package:lianji/ui/home.dart';
import 'package:lianji/ui/profile.dart';
import 'package:lianji/ui/statistics_page.dart';
import 'package:lianji/ui/active_workout.dart';
import 'package:lianji/ui/library.dart';
import 'package:lianji/ui/theme.dart';

void main() {
  testWidgets('玻璃内部实际透出背后颜色', (tester) async {
    if (const bool.fromEnvironment('CAPTURE_REDESIGN')) {
      for (final (family, path) in [
        ('Roboto', 'C:/Windows/Fonts/msyh.ttc'),
        (
          'MaterialIcons',
          '.tooling/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ),
      ]) {
        await (FontLoader(family)..addFont(
              Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
            ))
            .load();
      }
    }
    Future<Color> sample(Color background) async {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(BrandTheme.blue, Brightness.light),
          home: Center(
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox(
                width: 390,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: background),
                    Center(
                      child: SizedBox(
                        width: 366,
                        child: GlassNavigationBar(
                          selectedIndex: 0,
                          onDestinationSelected: (_) {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      late Color color;
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final img = await render.toImage();
        final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final offset = (40 * img.width + 195) * 4;
        color = Color.fromARGB(
          255,
          bytes!.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
        if (const bool.fromEnvironment('CAPTURE_REDESIGN')) {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'artifacts/ui-redesign/${RegExp(r"^version:\s*([\d.]+)", multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)}-glass-${background.r > .5 ? 'red' : 'blue'}.png',
          ).writeAsBytes(png!.buffer.asUint8List());
        }
        img.dispose();
      });
      return color;
    }

    final red = await sample(const Color(0xffe06070));
    final blue = await sample(const Color(0xff4080e0));
    expect(
      (red.r - blue.r).abs() + (red.b - blue.b).abs(),
      greaterThan(.25),
      reason: 'The rim must not paint an opaque gradient beneath the glass.',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('底栏独立分支切换中间帧排他且筛选保留', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = initialData();
    final controller = AppController(MemoryTrainingRepository(data), data);
    appRouter.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [controllerProvider.overrideWith((ref) => controller)],
        child: const LianjiApp(),
      ),
    );
    await tester.pumpAndSettle();
    const pages = [HomePage, TrainPage, StatisticsPage, ProfilePage];
    // Separate tab branches keep detail transitions and local state. Capture
    // intermediate frames; settling alone previously missed the user's bug.
    for (final index in [1, 2, 3, 0, 3, 2, 1, 0]) {
      await tester.tap(find.byKey(ValueKey('main-nav-$index')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < pages.length; i++) {
        expect(
          find.byType(pages[i]),
          i == index ? findsOneWidget : findsNothing,
          reason: 'tab $index: visible page $i',
        );
      }
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(const ValueKey('main-nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stats-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本周'));
    await tester.pumpAndSettle();
    for (final index in [3, 0, 2]) {
      await tester.tap(find.byKey(ValueKey('main-nav-$index')));
      await tester.pumpAndSettle();
    }
    expect(find.widgetWithText(OutlinedButton, '本周'), findsOneWidget);
    await controller.start();
    for (final (path, outgoing) in <(String, Type)>[
      ('/train/active', ActiveWorkoutPage),
      ('/library', LibraryPage),
      ('/appearance', AppearancePage),
    ]) {
      appRouter.go(path);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('main-nav-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byType(outgoing),
        findsNothing,
        reason: 'leaving $path must reach the statistics tab',
      );
      expect(find.byType(StatisticsPage), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  test('六主题玻璃导航选中文字对比度', () {
    for (final brand in BrandTheme.values) {
      for (final brightness in Brightness.values) {
        final theme = AppTheme.build(brand, brightness);
        final a = theme.colorScheme.primary.computeLuminance();
        final b = theme.extension<GlassPalette>()!.selection.computeLuminance();
        final ratio = (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$brand $brightness navigation',
        );
      }
    }
  });
  testWidgets('真实空态与玻璃导航往返保留活动训练', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = initialData();
    expect(data.settings['brand'], 'blue');
    expect(data.sessions, isEmpty);
    expect(data.measurements, isEmpty);
    final controller = AppController(MemoryTrainingRepository(data), data);
    appRouter.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [controllerProvider.overrideWith((ref) => controller)],
        child: const LianjiApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0,
    );
    expect(find.text('上肢训练'), findsNothing);
    expect(find.text('自由训练'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-training-muscle')), findsOneWidget);
    final nav = tester.getRect(find.byKey(const ValueKey('glass-navigation')));
    final primary = tester.getRect(
      find.byKey(const ValueKey('home-start-workout')),
    );
    expect(primary.bottom, lessThan(nav.top));
    expect(primary.height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('开始训练'));
    await tester.pumpAndSettle();
    final id = controller.data.active!.id;
    for (final index in [2, 3, 1, 0]) {
      await tester.tap(find.byKey(ValueKey('main-nav-$index')));
      await tester.pumpAndSettle();
      expect(controller.data.active!.id, id);
    }
    expect(find.text('继续训练'), findsOneWidget);
    await tester.tap(find.text('继续训练'));
    await tester.pumpAndSettle();
    expect(controller.data.sessions, hasLength(1));
    expect(controller.data.active!.id, id);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  const capture = bool.fromEnvironment('CAPTURE_REDESIGN');
  test('亮蓝主按钮各渐变端点支持大号粗体白字', () {
    final theme = AppTheme.build(BrandTheme.blue, Brightness.light);
    for (final color in ThemeTokens.homeActionColors(theme)) {
      expect(1.05 / (color.computeLuminance() + .05), greaterThanOrEqualTo(3));
    }
  });
  testWidgets('键盘弹出仍可完成下一组并保留输入', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final data = initialData();
    final session = Session.start('键盘验收', [
      WorkoutExercise.fromExercise(data.exercises.first),
    ]);
    session.exercises.first.sets.first.data.addAll({'weight': 40, 'reps': 8});
    data.sessions.add(session);
    final controller = AppController(MemoryTrainingRepository(data), data);
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
    await tester.pumpAndSettle();
    await tester.enterText(weight, '42.5');
    for (final index in [2, 1]) {
      await tester.tap(find.byKey(ValueKey('main-nav-$index')));
      await tester.pumpAndSettle();
    }
    expect(tester.widget<TextField>(weight).controller!.text, '42.5');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final action = find.widgetWithText(FilledButton, '完成下一组 · 杠铃卧推');
    final box = tester.getRect(action);
    expect(box.bottom, lessThanOrEqualTo(544));
    expect(box.height, greaterThanOrEqualTo(48));
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(controller.data.active!.completedSets, 1);
    expect(controller.data.active!.exercises.single.sets.single.weight, 42.5);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('选图同状态390x844及空态截图', (tester) async {
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadows);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (family, path) in [
      ('Roboto', 'C:/Windows/Fonts/msyh.ttc'),
      (
        'MaterialIcons',
        '.tooling/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    ]) {
      final loader = FontLoader(family)
        ..addFont(
          Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
        );
      await loader.load();
    }
    final at = DateTime(2026, 10, 19, 18);
    for (final populated in [true, false]) {
      final data = initialData();
      if (populated) {
        final template = data.templates.first;
        template.data['name'] = '上肢训练';
        template.data['exercises'] = data.exercises
            .take(5)
            .map((e) => WorkoutExercise.fromExercise(e).toJson())
            .toList();
        data.schedule['1'] = template.id;
        final session = Session.start('自由训练', [
          WorkoutExercise.fromExercise(data.exercises.first),
        ], at: DateTime(2026, 10, 19, 10));
        session.data['endedAt'] = DateTime(
          2026,
          10,
          19,
          10,
          32,
        ).toUtc().toIso8601String();
        session.exercises.first.sets.first.data.addAll({
          'weight': 40,
          'reps': 8,
          'completed': true,
          'completedAt': DateTime(
            2026,
            10,
            19,
            10,
            20,
          ).toUtc().toIso8601String(),
        });
        data.sessions.add(session);
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            controllerProvider.overrideWith(
              (ref) => AppController(MemoryTrainingRepository(data), data),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: AppTheme.build(BrandTheme.blue, Brightness.light),
            home: RepaintBoundary(
              key: boundary,
              child: AppScaffold(
                location: '/',
                child: HomePage(now: at),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/images/home-hero-jade.png'),
          tester.element(find.byType(HomePage)),
        );
        await precacheImage(
          const AssetImage('assets/icons/arm-flex.png'),
          tester.element(find.byType(HomePage)),
        );
        await precacheImage(
          const AssetImage('assets/icons/recent-dumbbell.png'),
          tester.element(find.byType(HomePage)),
        );
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (populated) {
        final nav = tester.getRect(
          find.byKey(const ValueKey('glass-navigation')),
        );
        final recent = tester.getRect(
          find.widgetWithText(ListTile, '10月19日 · 自由训练 · 32分钟'),
        );
        expect(recent.bottom + 4, lessThanOrEqualTo(nav.top));
        await tester.runAsync(() async {
          await File('artifacts/ui-redesign/layout-metrics.json').writeAsString(
            jsonEncode({
              'navTop': nav.top,
              'recentTop': recent.top,
              'recentBottom': recent.bottom,
            }),
          );
        });
      }
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final img = await render.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await Directory('artifacts/ui-redesign').create(recursive: true);
        await File(
          'artifacts/ui-redesign/home-${populated ? 'populated' : 'empty'}-390x844.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    debugDisableShadows = previousShadows;
  }, skip: !capture);
}
