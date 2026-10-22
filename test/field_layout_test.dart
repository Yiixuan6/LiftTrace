import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/main.dart';
import 'package:lianji/ui/backup_page.dart';
import 'package:lianji/ui/components.dart';
import 'package:lianji/ui/templates.dart';
import 'package:lianji/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        ),
  );
  Future<void> render(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
    BrandTheme brand = BrandTheme.blue,
  }) async {
    final d = initialData();
    tester.view.physicalSize = const Size(347, 780);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          controllerProvider.overrideWith(
            (ref) => AppController(MemoryTrainingRepository(d), d),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.build(brand, Brightness.light),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(347, 780),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('标签空值、有值、焦点和200%始终在框外，保留输入控制器', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    for (final scale in [1.0, 2.0]) {
      await render(
        tester,
        PageBody(
          title: '字段验收',
          children: [
            LabeledTextField(label: '总外部重量 kg', controller: controller),
          ],
        ),
        scale: scale,
      );
      final input = find.byKey(const ValueKey('input-总外部重量 kg'));
      final caption = find.byKey(const ValueKey('caption-总外部重量 kg'));
      for (final value in ['', '42.5']) {
        await tester.enterText(input, value);
        await tester.pumpAndSettle();
        final decorator = find.descendant(
          of: input,
          matching: find.byType(InputDecorator),
        );
        expect(
          tester.getBottomLeft(caption).dy + 7.9,
          lessThanOrEqualTo(tester.getTopLeft(decorator).dy),
        );
        expect(tester.widget<TextField>(input).decoration?.labelText, isNull);
        expect(
          identical(tester.widget<TextField>(input).controller, controller),
          isTrue,
        );
        expect(controller.text, value);
        expect(tester.takeException(), null);
      }
    }
  });
  testWidgets('导出和WebDAV按钮三品牌大小一致，禁用也一致，大字体自动单列', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brand in BrandTheme.values) {
      for (final scale in [1.0, 2.0]) {
        await render(tester, const BackupPage(), brand: brand, scale: scale);
        for (final key in ['local-file-actions', 'webdav-actions']) {
          final group = find.byKey(ValueKey(key));
          final buttons = find.descendant(
            of: group,
            matching: find.byWidgetPredicate(
              (w) => w is FilledButton || w is OutlinedButton,
            ),
          );
          expect(buttons, findsNWidgets(4));
          final sizes = buttons
              .evaluate()
              .map((e) => tester.getSize(find.byWidget(e.widget)))
              .toList();
          for (final size in sizes) {
            expect(size.width, closeTo(sizes.first.width, .01));
            expect(size.height, closeTo(sizes.first.height, .01));
          }
          if (key == 'webdav-actions') {
            expect(
              tester.widget<FilledButton>(buttons.first).onPressed,
              isNotNull,
            );
            expect(
              tester.widget<OutlinedButton>(buttons.at(1)).onPressed,
              isNull,
            );
          }
          if (scale == 2) {
            expect(
              tester.getTopLeft(buttons.at(1)).dy,
              greaterThan(tester.getBottomLeft(buttons.first).dy),
            );
          }
        }
        expect(tester.takeException(), null);
      }
    }
  });
  testWidgets('模板外置字段仍验证组数且保存原快照，不写训练实绩', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final d = initialData();
    // Keep repository and controller on the same explicit synthetic document.
    final controller = AppController(MemoryTrainingRepository(d), d);
    final id = d.templates.first.id;
    final before = jsonEncode(d.toJson());
    appRouter.go('/templates/$id');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [controllerProvider.overrideWith((ref) => controller)],
        child: const LianjiApp(),
      ),
    );
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('input-目标组数')).first;
    final caption = find.byKey(const ValueKey('caption-目标组数')).first;
    expect(
      tester.getBottomLeft(caption).dy + 7.9,
      lessThanOrEqualTo(
        tester
            .getTopLeft(
              find.descendant(of: input, matching: find.byType(InputDecorator)),
            )
            .dy,
      ),
    );
    await tester.enterText(input, '0');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('保存模板'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存模板'));
    await tester.pumpAndSettle();
    expect(find.text('请输入 1–100 组'), findsOneWidget);
    expect(jsonEncode(d.toJson()), before);
    await tester.ensureVisible(input);
    await tester.pumpAndSettle();
    await tester.enterText(input, '4');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('保存模板'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存模板'));
    await tester.pumpAndSettle();
    expect(find.byType(TemplatesPage), findsOneWidget);
    expect(controller.data.templates.first.id, id);
    expect(
      controller.data.templates.first.data['exercises'][0]['sets'].length,
      4,
    );
    expect(controller.data.sessions, isEmpty);
  });
}
