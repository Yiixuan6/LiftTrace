// Standalone profile probe, not the debug integration-test runner.
// Only synthetic UUID SQLite databases and the isolated design identity.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/l10n/app_strings.dart';
import 'package:lianji/main.dart';
import 'package:lianji/ui/liquid_glass.dart';
import 'fixtures/input_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final label = await const MethodChannel(
    'app.lianji.training/app-info',
  ).invokeMethod<String>('getApplicationName');
  if (label != '练迹设计验收') throw StateError('Isolated package required');
  await AppStrings.prepare();
  await LiquidGlassSurface.prepare();
  final directory = await getTemporaryDirectory();
  final results = <String, Object?>{
    'version': '0.2.12+14',
    'mode': 'profile',
    'readsExistingDatabase': false,
    'measurement':
        'scripted TextEditingValue callback to framework endOfFrame; physical IME latency excluded',
    'refractionReady': LiquidGlassSurface.refractionReady,
  };
  for (final count in [200, 1000]) {
    final repo = await SqliteTrainingRepository.open(
      path: '${directory.path}/input-profile-${newId()}.db',
    );
    await repo.save(inputFixture(count));
    final controller = AppController(repo, await repo.load());
    appRouter.go('/train/active');
    final root = GlobalKey();
    runApp(
      ProviderScope(
        key: UniqueKey(),
        overrides: [controllerProvider.overrideWith((ref) => controller)],
        child: KeyedSubtree(key: root, child: const LianjiApp()),
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    Element? target;
    void visit(Element element) {
      if (target == null &&
          element.widget is TextField &&
          element.widget.key == const ValueKey('input-总外部重量 kg')) {
        target = element;
      }
      element.visitChildren(visit);
    }

    (root.currentContext! as Element).visitChildren(visit);
    if (target == null) throw StateError('Probe field not found');
    await Scrollable.ensureVisible(target!, alignment: .3);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final field = (target!.widget as TextField).controller!;
    final samples = <int>[], builds = <int>[], rasters = <int>[];
    void timings(List<FrameTiming> frames) {
      for (final frame in frames) {
        builds.add(frame.buildDuration.inMicroseconds);
        rasters.add(frame.rasterDuration.inMicroseconds);
      }
    }

    SchedulerBinding.instance.addTimingsCallback(timings);
    for (var i = 0; i < 65; i++) {
      final watch = Stopwatch()..start();
      final text = '${30 + i / 10}';
      field.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      await SchedulerBinding.instance.endOfFrame;
      if (i >= 5) samples.add(watch.elapsedMicroseconds);
      await Future<void>.delayed(const Duration(milliseconds: 35));
    }
    await controller.flushInputs();
    await Future<void>.delayed(const Duration(seconds: 1));
    SchedulerBinding.instance.removeTimingsCallback(timings);
    final loaded = await repo.load();
    if (loaded.active!.exercises.last.sets.last.weight != 36.4) {
      throw StateError('Final scripted value did not persist');
    }
    int percentile(List<int> values) {
      if (values.isEmpty) throw StateError('No frame samples');
      values.sort();
      return values[((values.length - 1) * .95).ceil()];
    }

    results['$count'] = {
      'samples': samples.length,
      'inputToFrameworkFrameP95Micros': percentile(samples),
      'buildP95Micros': percentile(builds),
      'rasterP95Micros': percentile(rasters),
      'persisted': true,
      'latencyP95Within50ms': percentile(samples) <= 50000,
      'displayRefreshRateHz': View.of(root.currentContext!).display.refreshRate,
    };
    // Dispose mounted inputs before closing this synthetic database.
    runApp(const SizedBox());
    await SchedulerBinding.instance.endOfFrame;
    await repo.close();
  }
  await File(
    '${directory.path}/input-profile-report.json',
  ).writeAsString(jsonEncode(results), flush: true);
  debugPrint('INPUT_PROFILE_REPORT ${jsonEncode(results)}', wrapWidth: 4000);
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('合成输入性能验收完成'))),
    ),
  );
}
