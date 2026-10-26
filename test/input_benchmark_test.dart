import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import '../integration_test/fixtures/input_data.dart';
export '../integration_test/fixtures/input_data.dart' show inputFixture;

// Synthetic only; host timings are not device input-to-frame measurements.

void main() {
  test('合成200/1000次历史：串行输入保存基准', () async {
    final results = <String, Object>{};
    for (final n in [200, 1000]) {
      final d = inputFixture(n);
      final repo = MemoryTrainingRepository(d);
      final c = AppController(repo, await repo.load());
      final s = c.data.active!, e = s.exercises.first, row = e.sets.first;
      final timings = <int>[];
      for (var i = 0; i < 20; i++) {
        final watch = Stopwatch()..start();
        await c.editSet(s.id, e.id, row.id, {'weight': 40 + i / 10});
        timings.add(watch.elapsedMicroseconds);
      }
      timings.sort();
      results['$n'] = {'p95SaveMicros': timings[18], 'samples': timings.length};
      expect(
        (await repo.load()).active!.exercises.first.sets.first.weight,
        41.9,
      );
      c.dispose();
      await repo.close();
    }
    const baseline = bool.fromEnvironment('PERF_BASELINE');
    final dir = Directory('artifacts/input-0.2.12')
      ..createSync(recursive: true);
    File(
      '${dir.path}/${baseline ? 'before' : 'after'}-host.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  });
}
