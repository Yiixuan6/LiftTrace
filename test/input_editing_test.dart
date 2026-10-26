import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/main.dart';
import 'package:lianji/ui/active_workout.dart';
import 'package:lianji/ui/components.dart';
import 'package:lianji/ui/workout_set_row.dart';
import 'package:lianji/ui/home.dart' show HomePage;
import 'package:lianji/ui/statistics_page.dart';

class _Repo extends MemoryTrainingRepository {
  _Repo(super.initial);
  bool fail = false;
  Completer<void>? gate;
  int writes = 0;
  @override
  Future<void> saveSession(Session session, int revision) async {
    writes++;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('synthetic disk failure');
    await super.saveSession(session, revision);
  }
}

void main({bool native = false}) {
  late AppController c;
  late _Repo repo;
  Future<void> mount(WidgetTester tester, {bool fullApp = false}) async {
    if (!native) {
      tester.view.physicalSize = const Size(432, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    final d = initialData();
    final move = WorkoutExercise.fromExercise(d.exercises.first);
    move.data['sets'] = [
      for (var i = 0; i < 2; i++)
        (WorkoutSet.empty()..data.addAll({'weight': 40, 'reps': 8})).toJson(),
    ];
    d.sessions.add(Session.start('合成输入验收', [move]));
    repo = _Repo(d);
    c = AppController(repo, await repo.load());
    appRouter.go('/train/active');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [controllerProvider.overrideWith((ref) => c)],
        child: fullApp
            ? const LianjiApp()
            : const MaterialApp(home: Scaffold(body: ActiveWorkoutPage())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(WidgetTester tester) => find.byType(WorkoutSetRow).first;
  Finder input(String key, WidgetTester tester) => find.descendant(
    of: row(tester),
    matching: find.byKey(ValueKey('input-$key')),
  );

  testWidgets('数字逐次即时显示，异步确认及每秒计时不重建整页/其他组/根应用', (tester) async {
    await mount(tester, fullApp: true);
    final field = input('总外部重量 kg', tester);
    await tester.ensureVisible(field);
    await tester.showKeyboard(field);
    await tester.pumpAndSettle();
    final page = tester.widget(find.byType(PageBody).last);
    final other = tester.widget(find.byType(WorkoutSetRow).last);
    final root = tester.widget(find.byType(MaterialApp));
    final controller = tester.widget<TextField>(field).controller;
    final viewRevision = c.workoutRevision;
    for (final text in ['3', '37', '37.', '37.5', '37.', '37.25']) {
      await tester.enterText(field, text);
      await tester.pumpAndSettle();
      expect(controller!.text, text);
      expect(c.workoutRevision, viewRevision);
      if (!native) {
        // Fixed host metrics isolate input rebuilds from actual Android IME
        // inset/lifecycle events, which legitimately rebuild the native page.
        expect(
          identical(tester.widget(find.byType(PageBody).last), page),
          isTrue,
        );
        expect(
          identical(tester.widget(find.byType(WorkoutSetRow).last), other),
          isTrue,
        );
        expect(
          identical(tester.widget(find.byType(MaterialApp)), root),
          isTrue,
        );
      }
    }
    await tester.pump(const Duration(seconds: 2));
    if (!native) {
      expect(
        identical(tester.widget(find.byType(PageBody).last), page),
        isTrue,
      );
      expect(
        identical(tester.widget(find.byType(WorkoutSetRow).last), other),
        isTrue,
      );
    }
    await c.flushInputs();
    expect((await repo.load()).active!.exercises.first.sets.last.weight, 37.25);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('拼音组合不保存、不回写，组合结束且文本相同时仍提交，光标不回跳', (tester) async {
    await mount(tester);
    final note = input('逐组备注（可选）', tester);
    await tester.ensureVisible(note);
    await tester.showKeyboard(note);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'zhong',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      ),
    );
    await tester.pump();
    expect(repo.writes, 0);
    await expectLater(c.flushInputs(), throwsFormatException);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '中文',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    expect(repo.writes, 0);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '中文',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pumpAndSettle();
    await c.flushInputs();
    expect(repo.writes, 1);
    expect(
      (await repo.load()).active!.exercises.first.sets.last.data['note'],
      '中文',
    );
    expect(tester.widget<TextField>(note).controller!.selection.baseOffset, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('立即完成等待在途保存，完成组使用最后输入', (tester) async {
    await mount(tester);
    repo.gate = Completer<void>();
    final weight = input('总外部重量 kg', tester);
    await tester.ensureVisible(weight);
    await tester.enterText(weight, '52.5');
    await tester.pump();
    final complete = find.descendant(
      of: row(tester),
      matching: find.text('完成当前组'),
    );
    await tester.ensureVisible(complete);
    await tester.tap(complete);
    await tester.pump();
    expect(c.data.active!.completedSets, 0);
    repo.gate!.complete();
    await tester.pumpAndSettle();
    final saved = (await repo.load()).active!.exercises.first.sets.last;
    expect(saved.completed, isTrue);
    expect(saved.weight, 52.5);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('保存失败保留文本，完成不能越过失败，修正后可恢复保存', (tester) async {
    await mount(tester);
    repo.fail = true;
    final weight = input('总外部重量 kg', tester);
    await tester.ensureVisible(weight);
    await tester.enterText(weight, '52.5');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(weight).controller!.text, '52.5');
    expect((await repo.load()).active!.exercises.first.sets.last.weight, 40);
    await expectLater(c.flushInputs(), throwsA(anything));
    expect(c.data.active!.completedSets, 0);
    repo.fail = false;
    await tester.enterText(weight, '52.75');
    await tester.pumpAndSettle();
    await c.flushInputs();
    expect((await repo.load()).active!.exercises.first.sets.last.weight, 52.75);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('输入后立即复制/删除：等待保存并读取最新值，稳定ID和倒序不串组', (tester) async {
    await mount(tester);
    final ids = c.data.active!.exercises.first.sets.map((s) => s.id).toList();
    repo.gate = Completer<void>();
    final weight = input('总外部重量 kg', tester);
    await tester.ensureVisible(weight);
    await tester.enterText(weight, '56.25');
    await tester.pump();
    final copy = find.descendant(
      of: row(tester),
      matching: find.byTooltip('复制本组为未完成组'),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(copy);
    await tester.pumpAndSettle();
    await tester.tap(copy);
    await tester.pump();
    expect(c.data.active!.exercises.first.sets.length, 2);
    repo.gate!.complete();
    await tester.pumpAndSettle();
    final sets = c.data.active!.exercises.first.sets;
    expect(sets.length, 3);
    expect(sets.take(2).map((s) => s.id), ids);
    expect(sets.last.weight, 56.25);
    expect(sets.last.completed, isFalse);
    final copiedId = sets.last.id;
    final remove = find.descendant(
      of: row(tester),
      matching: find.byTooltip('删除本组'),
    );
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(c.data.active!.exercises.first.sets.map((s) => s.id), ids);
    final raw =
        (await repo.load()).active!.exercises.first.data['sets'] as List;
    expect(raw.singleWhere((s) => s['id'] == copiedId)['deleted'], isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Dock离开等待输入落库，返回保留原控制器与最后输入', (tester) async {
    await mount(tester, fullApp: true);
    repo.gate = Completer<void>();
    final weight = input('总外部重量 kg', tester);
    await tester.ensureVisible(weight);
    await tester.enterText(weight, '61.5');
    await tester.pump();
    final fieldController = tester.widget<TextField>(weight).controller;
    await tester.tap(find.byKey(const ValueKey('main-nav-3')));
    await tester.pump();
    expect(appRouter.routeInformationProvider.value.uri.path, '/train/active');
    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/profile');
    expect((await repo.load()).active!.exercises.first.sets.last.weight, 61.5);
    await tester.tap(find.byKey(const ValueKey('main-nav-1')));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/train/active');
    expect(
      identical(tester.widget<TextField>(weight).controller, fieldController),
      isTrue,
    );
    expect(fieldController!.text, '61.5');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('隐藏首页和统计不随击键重算，重返统计刷新并保留子分区', (tester) async {
    await mount(tester, fullApp: true);
    final initial = c.data.active!, initialMove = initial.exercises.first;
    await c.completeSet(initial.id, initialMove.id, initialMove.sets.first.id);
    appRouter.go('/stats');
    await tester.pumpAndSettle();
    await tester.tap(find.text('动作趋势'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stats-exercise')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('杠铃卧推 · 外部负重').last);
    await tester.pumpAndSettle();
    final selected = tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('stats-exercise')),
        )
        .initialValue;
    appRouter.go('/');
    await tester.pumpAndSettle();
    appRouter.go('/train/active');
    await tester.pumpAndSettle();
    final stats = find.descendant(
      of: find.byType(StatisticsPage, skipOffstage: false),
      matching: find.byType(PageBody, skipOffstage: false),
      skipOffstage: false,
    );
    final home = find.descendant(
      of: find.byType(HomePage, skipOffstage: false),
      matching: find.byType(CustomScrollView, skipOffstage: false),
      skipOffstage: false,
    );
    final oldStats = tester.widget(stats), oldHome = tester.widget(home);
    final s = c.data.active!, e = s.exercises.first, set = e.sets.last;
    await c.editSet(s.id, e.id, set.id, {'weight': 73.5});
    await c.completeSet(s.id, e.id, set.id);
    await tester.pumpAndSettle();
    expect(identical(tester.widget(stats), oldStats), isTrue);
    expect(identical(tester.widget(home), oldHome), isTrue);
    appRouter.go('/stats');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<int>>(
            find.byKey(const ValueKey('stats-view')),
          )
          .selected,
      {1},
    );
    expect(identical(tester.widget(stats), oldStats), isFalse);
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('stats-exercise')),
          )
          .initialValue,
      selected,
    );
    expect(
      tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .lineBarsData
          .first
          .spots
          .last
          .y,
      73.5,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
