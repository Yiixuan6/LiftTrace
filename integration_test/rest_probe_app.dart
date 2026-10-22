// Standalone QA entry: no integration-test runner, no training database.
// Used because the OEM can kill a background test VM and the Flutter runner
// then force-stops its package, cancelling the very alarm being measured.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/main.dart';
import 'package:lianji/platform/reminders.dart';
import 'package:lianji/ui/active_workout.dart';
import 'package:lianji/ui/liquid_glass.dart';

class _ProbeReminders extends RestReminders {
  _ProbeReminders(this.marker);
  final File marker;
  @override
  Future<RestReminderStatus> schedule(DateTime deadline) async {
    final status = await super.schedule(deadline);
    {
      await marker.writeAsString(
        jsonEncode({
          'deadline': deadline.toUtc().toIso8601String(),
          'source': 'real training page, in-memory synthetic set',
          'ready': status.ready,
          'notificationsAllowed': status.notificationsAllowed,
          'exactAllowed': status.exactAllowed,
          'popupAllowed': status.popupAllowed,
          'vibrationAllowed': status.vibrationAllowed,
        }),
        flush: true,
      );
    }
    return status;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('正在准备隔离提醒验收…'))),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  debugPrint('REST_PROBE firstFrame=true');
  final temp = await getExternalStorageDirectory();
  if (temp == null) {
    throw StateError('Isolated external diagnostics unavailable');
  }
  debugPrint('REST_PROBE cacheReady=true');
  const token = String.fromEnvironment('QA_TOKEN');
  if (!temp.path.contains('/app.lianji.training.qa.design/') ||
      !RegExp(r'^[a-f0-9]{32}$').hasMatch(token)) {
    throw StateError(
      'Standalone probe requires the isolated QA package and token',
    );
  }
  await temp.create(recursive: true);
  final reminders = _ProbeReminders(File('${temp.path}/rest-qa-$token.json'));
  try {
    await reminders.initialize();
    await File('${temp.path}/rest-init-$token.json').writeAsString(
      jsonEncode({'initialized': true, 'trainingDatabaseRead': false}),
      flush: true,
    );
  } catch (error) {
    await File('${temp.path}/rest-init-$token.json').writeAsString(
      jsonEncode({
        'initialized': false,
        'errorCode': error is PlatformException
            ? error.code
            : 'initialize_failed',
        'trainingDatabaseRead': false,
      }),
      flush: true,
    );
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              '隔离验收初始化失败：${error is PlatformException ? error.code : "initialize_failed"}',
            ),
          ),
        ),
      ),
    );
    return;
  }
  debugPrint('REST_PROBE notificationsReady=true');
  // One-off cleanup is explicit and used only for our failed in-memory probe.
  // Normal runs must refuse to replace an existing user's reminder.
  if (const bool.fromEnvironment('QA_CLEAN_OWN_PROBE')) {
    await reminders.cancel();
  }
  if ((await reminders.plugin.pendingNotificationRequests()).any(
    (n) => n.id == RestReminders.notificationId,
  )) {
    throw StateError('Refuse to replace an existing QA rest alarm');
  }
  await LiquidGlassSurface.prepare();
  debugPrint('REST_PROBE graphicsReady=true');
  final data = initialData();
  final move = WorkoutExercise.fromExercise(data.exercises.first);
  move.data['restSeconds'] = 15;
  move.sets.first.data.addAll({'weight': 20, 'reps': 8});
  data.sessions.add(Session.start('隔离后台提醒验收', [move]));
  final controller = AppController(MemoryTrainingRepository(data), data);
  appRouter.go('/train/active');
  runApp(
    ProviderScope(
      overrides: [
        controllerProvider.overrideWith((ref) => controller),
        remindersProvider.overrideWithValue(reminders),
      ],
      child: const LianjiApp(),
    ),
  );
}
