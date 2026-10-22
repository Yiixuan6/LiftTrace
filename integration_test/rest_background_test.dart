import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lianji/platform/reminders.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/main.dart';
import 'package:lianji/ui/active_workout.dart';
import 'package:lianji/ui/liquid_glass.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('真实系统后台送达与震动通道，不访问训练库', (tester) async {
    final temp = await getTemporaryDirectory();
    expect(temp.path, contains('app.lianji.training.qa'));
    const token = String.fromEnvironment('QA_TOKEN');
    expect(RegExp(r'^[a-f0-9]{32}$').hasMatch(token), true);
    final marker = File('${temp.path}/rest-qa-$token.json');
    final reminders = RestReminders();
    await reminders.initialize();
    expect(
      (await reminders.plugin.pendingNotificationRequests()).where(
        (n) => n.id == RestReminders.notificationId,
      ),
      isEmpty,
      reason: 'Refuse to replace an existing QA user rest reminder',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('组间休息后台提醒验收\n仅合成通知，不读取训练记录'))),
      ),
    );
    var status = await reminders.status();
    debugPrint(
      'REST_PERMISSIONS notifications=${status.notificationsAllowed} exact=${status.exactAllowed} popup=${status.popupAllowed} vibration=${status.vibrationAllowed}',
    );
    if (!status.notificationsAllowed || !status.exactAllowed) {
      await reminders.requestPermissions(precise: true);
      status = await reminders.status();
    }
    expect(status.ready, true, reason: status.message);
    await LiquidGlassSurface.prepare();
    final data = initialData();
    final move = WorkoutExercise.fromExercise(data.exercises.first);
    move.data['restSeconds'] = 15;
    move.sets.first.data.addAll({'weight': 20, 'reps': 8});
    data.sessions.add(Session.start('隔离提醒验收', [move]));
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
    try {
      await tester.tap(find.textContaining('完成下一组 ·'));
      await tester.pumpAndSettle();
      expect(controller.data.active!.completedSets, 1);
      final deadline = DateTime.parse(
        controller.data.settings['restDeadline'] as String,
      );
      expect(
        (await reminders.plugin.pendingNotificationRequests()).any(
          (n) => n.id == RestReminders.notificationId,
        ),
        true,
      );
      await marker.writeAsString(
        jsonEncode({'deadline': deadline.toUtc().toIso8601String()}),
        flush: true,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 26)),
      );
      final active = await reminders.plugin.getActiveNotifications();
      expect(
        active.any(
          (n) => n.id == RestReminders.notificationId && n.title == '休息结束',
        ),
        true,
      );
      expect(
        (await reminders.plugin.pendingNotificationRequests()).any(
          (n) => n.id == RestReminders.notificationId,
        ),
        false,
      );
      expect(controller.data.active!.completedSets, 1);
      debugPrint(
        'REST_BACKGROUND_DELIVERED=true channelVibration=true completedSet=true noTrainingDatabase=true',
      );
    } finally {
      await reminders.cancel();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
