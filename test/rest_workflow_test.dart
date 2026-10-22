import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/main.dart';
import 'package:lianji/platform/reminders.dart';
import 'package:lianji/ui/active_workout.dart';

class _Reminders extends RestReminders {
  final targets = <DateTime>[];
  var cancels = 0, prompts = 0;
  bool fail = false, allowed = true;
  @override
  Future<RestReminderStatus> status() async => RestReminderStatus(
    supported: true,
    notificationsAllowed: allowed,
    exactAllowed: true,
    popupAllowed: true,
    vibrationAllowed: true,
  );
  @override
  Future<bool> requestPermissions({bool precise = false}) async {
    prompts++;
    return allowed;
  }

  @override
  Future<RestReminderStatus> schedule(DateTime deadline) async {
    if (fail) throw StateError('synthetic platform failure');
    targets.add(deadline);
    return status();
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

void main() {
  Future<AppController> mount(WidgetTester tester, _Reminders reminders) async {
    tester.view.physicalSize = const Size(432, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = initialData();
    final move = WorkoutExercise.fromExercise(data.exercises.first);
    move.sets.first.data.addAll({'weight': 20, 'reps': 8});
    data.sessions.add(Session.start('隔离测试', [move]));
    final controller = AppController(MemoryTrainingRepository(data), data);
    appRouter.go('/train/active');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          controllerProvider.overrideWith((ref) => controller),
          remindersProvider.overrideWithValue(reminders),
        ],
        child: const LianjiApp(),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('完成组保存后安排后台提醒，离开页面不取消', (tester) async {
    final reminders = _Reminders();
    final controller = await mount(tester, reminders);
    await tester.tap(find.textContaining('完成下一组 ·'));
    await tester.pumpAndSettle();
    expect(controller.data.active!.completedSets, 1);
    expect(reminders.targets, hasLength(1));
    expect(
      controller.data.settings['restDeadline'],
      reminders.targets.single.toUtc().toIso8601String(),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(reminders.cancels, 0);
  });
  testWidgets('暂停撤销、继续重排、延长更新、取消清除，结束同步撤销', (tester) async {
    final reminders = _Reminders();
    final controller = await mount(tester, reminders);
    await tap(tester, '60 秒');
    final first = reminders.targets.last;
    await tap(tester, '+30 秒');
    expect(
      reminders.targets.last.difference(first).inSeconds,
      inInclusiveRange(28, 31),
    );
    await tap(tester, '暂停');
    expect(reminders.cancels, 1);
    expect(controller.data.settings['restDeadline'], null);
    expect(controller.data.settings['restRemaining'], greaterThan(0));
    await tap(tester, '继续');
    expect(reminders.targets, hasLength(3));
    await tap(tester, '结束休息');
    expect(reminders.cancels, 2);
    expect(controller.data.settings['restDeadline'], null);
    expect(controller.data.settings.containsKey('restRemaining'), false);
    await tap(tester, '60 秒');
    await tap(tester, '结束训练');
    await tap(tester, '结束并保存');
    expect(controller.data.active, null);
    expect(reminders.cancels, 3);
    expect(controller.data.settings['restDeadline'], null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('拒权不反复弹窗，系统失败不丢完成组与截止时间', (tester) async {
    final reminders = _Reminders()..allowed = false;
    final controller = await mount(tester, reminders);
    await tap(tester, '60 秒');
    await tap(tester, '90 秒');
    expect(reminders.prompts, 1);
    // Dismiss the actionable permission notice before using the bottom CTA.
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    reminders.fail = true;
    await tester.ensureVisible(find.textContaining('完成下一组 ·'));
    await tester.tap(find.textContaining('完成下一组 ·'));
    await tester.pumpAndSettle();
    expect(controller.data.active!.completedSets, 1);
    expect(controller.data.settings['restDeadline'], isNotNull);
    expect(find.text('本组和计时已保存，系统提醒暂不可用'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('选择时长后下一组沿用，暂停延长不重启，底部跳过不改训练组', (tester) async {
    final reminders = _Reminders();
    final controller = await mount(tester, reminders);
    await tap(tester, '60 秒');
    expect(controller.data.settings['restPresetSeconds'], 60);
    await tester.tap(find.textContaining('完成下一组 ·'));
    await tester.pumpAndSettle();
    expect(
      reminders.targets.last.difference(DateTime.now()).inSeconds,
      inInclusiveRange(57, 60),
    );
    expect(
      (await controller.repository.load()).settings['restPresetSeconds'],
      60,
    );
    await tester.tap(find.byKey(const ValueKey('rest-quick-pause')));
    await tester.pumpAndSettle();
    final saved = controller.data.settings['restRemaining'] as int;
    final count = reminders.targets.length;
    await tap(tester, '+30 秒');
    expect(controller.data.settings['restDeadline'], null);
    expect(controller.data.settings['restRemaining'], saved + 30);
    expect(reminders.targets, hasLength(count));
    await tester.tap(find.byKey(const ValueKey('rest-skip')));
    await tester.pumpAndSettle();
    expect(controller.data.settings['restDeadline'], null);
    expect(controller.data.settings.containsKey('restRemaining'), false);
    expect(controller.data.settings['restPresetSeconds'], 60);
    expect(controller.data.active!.completedSets, 1);
    expect(find.byKey(const ValueKey('rest-quick-controls')), findsNothing);
    await controller.change(
      (d) => d.settings['restDeadline'] = DateTime.now()
          .subtract(const Duration(seconds: 1))
          .toUtc()
          .toIso8601String(),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('休息结束'), findsOneWidget);
    expect(find.text('暂停'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
