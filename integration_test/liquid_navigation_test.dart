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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('液态底栏原生GPU隔离内存画面与切换采样', (tester) async {
    await LiquidGlassSurface.prepare();
    expect(LiquidGlassSurface.refractionReady, isTrue);
    final data = initialData();
    data.settings['brand'] = 'blue';
    data.settings['appearance'] = 'light';
    final controller = AppController(MemoryTrainingRepository(data), data);
    final boundary = GlobalKey();
    final folder = Directory(
      '${(await getTemporaryDirectory()).path}/liquid-navigation-qa',
    );
    await folder.create(recursive: true);
    appRouter.go('/');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          overrides: [controllerProvider.overrideWith((ref) => controller)],
          child: const LianjiApp(),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/home-hero-jade.png'),
        tester.element(find.byType(HomePage)),
      );
    });
    await tester.pumpAndSettle();
    Future<void> capture(String name) => tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(
        pixelRatio: tester.view.devicePixelRatio,
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${folder.path}/$name.png',
      ).writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
    await capture('home');
    const pages = [HomePage, TrainPage, StatisticsPage, ProfilePage];
    final selections = [1, 2, 3, 0, 3, 2, 1, 0, 1, 0];
    for (var n = 0; n < selections.length; n++) {
      final selected = selections[n];
      await tester.tap(find.byKey(ValueKey('main-nav-$selected')));
      await tester.pump();
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump(Duration(milliseconds: frame == 0 ? 16 : 80));
        for (var i = 0; i < pages.length; i++) {
          expect(
            find.byType(pages[i]),
            i == selected ? findsOneWidget : findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
        await capture('${n.toString().padLeft(2, '0')}-$frame');
      }
      await tester.pumpAndSettle();
    }
    expect(controller.data.sessions, isEmpty);
    debugPrint('LIQUID_NAVIGATION_GPU=true memoryOnly=true screenshots=30');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
