import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/main.dart';
import 'package:lianji/ui/home.dart';
import 'package:lianji/ui/profile.dart';
import 'package:lianji/ui/statistics_page.dart';
import 'package:lianji/ui/liquid_glass.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android 隔离 SQLite 真实训练流程', (tester) async {
    await LiquidGlassSurface.prepare();
    debugPrint('NAV_LIQUID_REFRACTION=${LiquidGlassSurface.refractionReady}');
    final temp = await getTemporaryDirectory();
    final path = '${temp.path}/qa-${newId()}.db';
    final repo = await SqliteTrainingRepository.open(path: path);
    final controller = AppController(repo, await repo.load());
    final boundary = GlobalKey();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await render.toImage(pixelRatio: 1);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory('${temp.path}/style-review');
      await folder.create(recursive: true);
      await File(
        '${folder.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      img.dispose();
    }

    appRouter.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [controllerProvider.overrideWith((ref) => controller)],
        child: RepaintBoundary(key: boundary, child: const LianjiApp()),
      ),
    );
    await tester.pumpAndSettle();
    await capture('home');
    await tester.tap(find.text('开始训练'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('添加动作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加动作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('杠铃卧推'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('input-总外部重量 kg')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('input-总外部重量 kg')), '40');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('input-次数')), '8');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('input-总外部重量 kg'))).dy,
      greaterThanOrEqualTo(
        tester
                .getBottomLeft(find.byKey(const ValueKey('caption-总外部重量 kg')))
                .dy +
            8,
      ),
    );
    await capture('active-fields');
    await tester.tap(find.text('完成下一组 · 杠铃卧推'));
    await tester.pumpAndSettle();
    expect(controller.data.active!.completedSets, 1);
    final id = controller.data.active!.id;
    const pages = [HomePage, TrainPage, StatisticsPage, ProfilePage];
    for (final index in [1, 2, 3, 0, 3, 2, 1, 0]) {
      await tester.tap(find.byKey(ValueKey('main-nav-$index')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 0; i < pages.length; i++) {
        expect(
          find.byType(pages[i]),
          i == index ? findsOneWidget : findsNothing,
          reason: 'Android tab $index visible page $i',
        );
      }
      expect(controller.data.active!.id, id);
      expect(controller.data.active!.completedSets, 1);
      if (index == 1) await capture('train');
      if (index == 2) await capture('statistics');
      if (index == 3) await capture('profile');
    }
    await tester.tap(find.byKey(const ValueKey('main-nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('动作趋势'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stats-exercise')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('杠铃卧推 · 外部负重').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .lineBarsData
          .single
          .spots
          .single
          .y,
      40,
    );
    await tester.tap(find.byKey(const ValueKey('main-nav-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('main-nav-2')));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
    await capture('statistics-trend');
    expect(controller.data.active!.id, id);
    await tester.tap(find.byKey(const ValueKey('main-nav-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续训练'));
    await tester.pumpAndSettle();
    expect(controller.data.active!.exercises.single.sets.single.weight, 40);
    await controller.pause(id);
    expect(controller.data.active!.paused, true);
    await controller.pause(id);
    await controller.finish(id);
    await tester.pumpAndSettle();
    expect(controller.data.active, null);
    appRouter.go('/templates/${controller.data.templates.first.id}');
    await tester.pumpAndSettle();
    await capture('template-fields');
    appRouter.go('/backup');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('webdav-actions')));
    await tester.pumpAndSettle();
    final actions = find.descendant(
      of: find.byKey(const ValueKey('webdav-actions')),
      matching: find.byWidgetPredicate(
        (w) => w is FilledButton || w is OutlinedButton,
      ),
    );
    expect(actions, findsNWidgets(4));
    final actionSize = tester.getSize(actions.first);
    for (final action in actions.evaluate()) {
      expect(tester.getSize(find.byWidget(action.widget)), actionSize);
    }
    await capture('backup-actions');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await repo.close();
    final reopened = await SqliteTrainingRepository.open(path: path);
    final restored = await reopened.load();
    expect(restored.sessions.single.completedSets, 1);
    expect(restored.sessions.single.exercises.single.sets.single.weight, 40);
    await reopened.close();
    // This file is in the QA app cache. Never use the production lianji.db.
  });
}
