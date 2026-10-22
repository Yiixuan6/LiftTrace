import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/main.dart';
import 'package:lianji/ui/profile.dart';
import 'package:lianji/ui/active_workout.dart';
import 'package:lianji/ui/theme.dart';

void main() {
  testWidgets('跟随系统响应变化，手动模式固定且切主题保留输入', (tester) async {
    tester.view.physicalSize = const Size(432, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    final d = initialData(),
        s = Session.start('主题输入', [
          WorkoutExercise.fromExercise(initialData().exercises.first),
        ]);
    d.sessions.add(s);
    final c = AppController(MemoryTrainingRepository(d), d);
    appRouter.go('/train/active');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [controllerProvider.overrideWith((ref) => c)],
        child: const LianjiApp(),
      ),
    );
    await tester.pumpAndSettle();
    final title = find.text('正在训练');
    expect(Theme.of(tester.element(title)).brightness, Brightness.light);
    await tester.ensureVisible(find.byKey(const ValueKey('input-总外部重量 kg')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('input-总外部重量 kg')),
      '37.5',
    );
    await tester.pumpAndSettle();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('input-总外部重量 kg'))),
      ).brightness,
      Brightness.dark,
    );
    await c.change((d) {
      d.settings['appearance'] = 'light';
      d.settings['brand'] = 'blue';
    });
    await tester.pumpAndSettle();
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('input-总外部重量 kg'))),
      ).brightness,
      Brightness.light,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('input-总外部重量 kg')))
          .controller!
          .text,
      '37.5',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('任一字段仍无效时，另一个有效字段不会解除完成保护', (tester) async {
    tester.view.physicalSize = const Size(432, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final d = initialData(),
        s = Session.start('验证输入', [
          WorkoutExercise.fromExercise(initialData().exercises.first),
        ]);
    s.exercises.first.sets.first.data.addAll({'weight': 40, 'reps': 8});
    d.sessions.add(s);
    final c = AppController(MemoryTrainingRepository(d), d);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [controllerProvider.overrideWith((ref) => c)],
        child: MaterialApp(
          theme: AppTheme.build(BrandTheme.orange, Brightness.light),
          home: const Scaffold(body: ActiveWorkoutPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('input-总外部重量 kg')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('input-总外部重量 kg')),
      'invalid',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('input-次数')), '10');
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成下一组 · 杠铃卧推'));
    await tester.pumpAndSettle();
    expect(c.data.active!.completedSets, 0);
    await tester.enterText(
      find.byKey(const ValueKey('input-总外部重量 kg')),
      '42.5',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成下一组 · 杠铃卧推'));
    await tester.pumpAndSettle();
    expect(c.data.active!.completedSets, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('首页到真实训练：新增动作、填写并完成一组', (tester) async {
    tester.view.physicalSize = const Size(432, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final d = initialData(), c = AppController(MemoryTrainingRepository(d), d);
    appRouter.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [controllerProvider.overrideWith((ref) => c)],
        child: const LianjiApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始训练'));
    await tester.pumpAndSettle();
    expect(c.data.active, isNotNull);
    await tester.ensureVisible(find.text('添加动作'));
    await tester.tap(find.text('添加动作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('杠铃卧推'));
    await tester.pumpAndSettle();
    expect(c.data.active!.exercises.length, 1);
    await tester.ensureVisible(find.byKey(const ValueKey('input-总外部重量 kg')));
    await tester.enterText(find.byKey(const ValueKey('input-总外部重量 kg')), '40');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('input-次数')), '8');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('完成当前组'));
    await tester.tap(find.text('完成当前组'));
    await tester.pumpAndSettle();
    expect(c.data.active!.completedSets, 1);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('外观预览不改变配置；应用后持久化', (tester) async {
    final d = initialData(), repo = MemoryTrainingRepository(initialData());
    // Simulate an existing user's explicit orange choice, retained on upgrade.
    d.settings['brand'] = 'orange';
    final c = AppController(repo, d);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [controllerProvider.overrideWith((ref) => c)],
        child: MaterialApp(
          theme: AppTheme.build(BrandTheme.orange, Brightness.light),
          home: const Scaffold(body: AppearancePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('冰川蓝'));
    await tester.pumpAndSettle();
    expect(c.data.settings['brand'], 'orange');
    await tester.ensureVisible(find.text('应用外观'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用外观'));
    await tester.pumpAndSettle();
    expect((await repo.load()).settings['brand'], 'blue');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('六套配色主要文字对比度满足 4.5:1', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
    }

    for (final brand in BrandTheme.values) {
      for (final mode in Brightness.values) {
        final s = AppTheme.build(brand, mode).colorScheme;
        expect(contrast(s.primary, s.onPrimary), greaterThanOrEqualTo(4.5));
        expect(contrast(s.surface, s.onSurface), greaterThanOrEqualTo(4.5));
        expect(
          contrast(s.primaryContainer, s.onPrimaryContainer),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });
}
