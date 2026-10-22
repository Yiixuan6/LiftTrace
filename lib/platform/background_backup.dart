import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import '../data/repository.dart';
import '../data/webdav.dart';

@pragma('vm:entry-point')
void backupDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    final credentials = DavCredentialStore();
    SqliteTrainingRepository? repo;
    WebDavClient? client;
    try {
      repo = await SqliteTrainingRepository.open();
      final data = await repo.load();
      if (data.settings['autoBackup'] != true) return true;
      final config = await credentials.read();
      if (config == null) return true;
      final previous = await credentials.readStatus();
      if (previous['revision'] == data.revision) return true;
      client = WebDavClient(config);
      await client.upload(data);
      await credentials.status({
        'revision': data.revision,
        'successAt': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      final previous = await credentials.readStatus();
      await credentials.status({
        ...previous,
        'error': '自动备份失败，将在联网后重试；本地训练不受影响',
      });
      return false;
    } finally {
      client?.close();
      await repo?.close();
    }
  });
}

class BackgroundBackup {
  static Future<void> initialize() async {
    if (Platform.isAndroid) await Workmanager().initialize(backupDispatcher);
  }

  static Future<void> schedule() async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerOneOffTask(
      'lianji-backup-change',
      'backup',
      existingWorkPolicy: ExistingWorkPolicy.keep,
      initialDelay: const Duration(seconds: 45),
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
    // Periodic compensation handles changes occurring while a one-off is running.
    await Workmanager().registerPeriodicTask(
      'lianji-backup-periodic',
      'backup',
      frequency: const Duration(hours: 6),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> cancel() async {
    if (Platform.isAndroid) {
      await Workmanager().cancelByUniqueName('lianji-backup-change');
      await Workmanager().cancelByUniqueName('lianji-backup-periodic');
    }
  }
}
