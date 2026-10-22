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
import 'package:lianji/platform/reminders.dart';
import 'package:lianji/ui/active_workout.dart';
import 'package:lianji/ui/components.dart';
import 'package:lianji/ui/theme.dart';

class _ReadyReminders extends RestReminders {
  @override
  Future<RestReminderStatus> status() async => const RestReminderStatus(
    supported: true,
    notificationsAllowed: true,
    exactAllowed: true,
    popupAllowed: true,
    vibrationAllowed: true,
  );
}

void main() {
  testWidgets('休息底部操作六外观、窄屏/横屏/平板200%无溢出', (tester) async {
    const capture = bool.fromEnvironment('CAPTURE_REST_FIX');
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (capture) {
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
    for (final brand in BrandTheme.values) {
      for (final brightness in Brightness.values) {
        for (final state in ['running', 'paused', 'finished']) {
          for (final (size, scale) in [
            (const Size(347, 780), 1.0),
            (const Size(347, 780), 2.0),
            (const Size(844, 390), 2.0),
            (const Size(900, 1280), 2.0),
          ]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            final data = initialData();
            final move = WorkoutExercise.fromExercise(data.exercises.first);
            move.sets.first.data.addAll({'weight': 40, 'reps': 8});
            data.sessions.add(Session.start('合成休息验收', [move]));
            data.settings['restPresetSeconds'] = 60;
            if (state == 'paused') {
              data.settings['restRemaining'] = 60;
            } else {
              data.settings['restDeadline'] = DateTime.now()
                  .add(Duration(seconds: state == 'running' ? 60 : -1))
                  .toUtc()
                  .toIso8601String();
            }
            final controller = AppController(
              MemoryTrainingRepository(data),
              data,
            );
            final key = GlobalKey();
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  controllerProvider.overrideWith((ref) => controller),
                  remindersProvider.overrideWithValue(_ReadyReminders()),
                ],
                child: MaterialApp(
                  locale: const Locale('zh', 'CN'),
                  supportedLocales: const [Locale('zh', 'CN')],
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  theme: AppTheme.build(brand, brightness),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: RepaintBoundary(
                      key: key,
                      child: const AppScaffold(
                        location: '/train/active',
                        child: ActiveWorkoutPage(),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              null,
              reason: '$brand $brightness $state $size $scale',
            );
            expect(
              find.byKey(const ValueKey('rest-skip')),
              state == 'finished' ? findsNothing : findsOneWidget,
            );
            if (state != 'finished') {
              expect(
                tester.getRect(find.byKey(const ValueKey('rest-skip'))).bottom,
                lessThanOrEqualTo(size.height),
              );
              expect(
                find.byTooltip(state == 'paused' ? '继续休息' : '暂停休息'),
                findsOneWidget,
              );
            }
            expect(controller.data.active!.completedSets, 0);
            if (capture && size.width == 347) {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              await tester.runAsync(() async {
                final img = await boundary.toImage(pixelRatio: 1);
                final bytes = await img.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final folder = Directory('artifacts/rest-fix-0.2.9/screenshots')
                  ..createSync(recursive: true);
                await File(
                  '${folder.path}/${brand.name}-${brightness.name}-$state-${scale.toInt()}x.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                img.dispose();
              });
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          }
        }
      }
    }
  });
}
