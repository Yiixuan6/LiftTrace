import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/main.dart';
import 'package:lianji/platform/reminders.dart';
import 'package:lianji/ui/active_workout.dart';
import 'package:lianji/ui/workout_set_row.dart';

class _Reminders extends RestReminders {
  @override
  Future<RestReminderStatus> status() async => const RestReminderStatus(
    supported: true,
    notificationsAllowed: true,
    exactAllowed: true,
    popupAllowed: true,
    vibrationAllowed: true,
  );
  @override
  Future<RestReminderStatus> schedule(DateTime deadline) => status();
}

void main() {
  final boundary = GlobalKey();
  Future<AppController> mount(
    WidgetTester tester, {
    bool history = false,
    bool multipleMoves = false,
    double textScale = 1,
  }) async {
    if (const bool.fromEnvironment('CAPTURE_SET_ORDER')) {
      // Load before the first text layout; later loading leaves Ahem cached.
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
    tester.view.physicalSize = const Size(432, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = initialData();
    final move = WorkoutExercise.fromExercise(
      data.exercises.firstWhere((e) => e.kind == LoadKind.external),
    );
    move.data['sets'] = [
      for (var i = 1; i <= 3; i++)
        (WorkoutSet.empty()..data.addAll({'weight': i * 10, 'reps': i + 5}))
            .toJson(),
    ];
    final session = Session.start('隔离组序测试', [
      move,
      if (multipleMoves)
        WorkoutExercise.fromExercise(
          data.exercises.firstWhere(
            (e) => e.kind == LoadKind.external && e.id != move.exercise.id,
          ),
        ),
    ]);
    if (history) session.data['endedAt'] = stamp();
    data.sessions.add(session);
    final controller = AppController(MemoryTrainingRepository(data), data);
    appRouter.go(history ? '/history/${session.id}' : '/train/active');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          controllerProvider.overrideWith((ref) => controller),
          remindersProvider.overrideWithValue(_Reminders()),
        ],
        child: RepaintBoundary(
          key: boundary,
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: const LianjiApp(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Finder row(String id) => find.byKey(ValueKey(id));
  Finder weight(String id) => find.descendant(
    of: row(id),
    matching: find.byWidgetPredicate(
      (w) => w is TextField && w.key == const ValueKey('input-总外部重量 kg'),
    ),
  );
  List<WorkoutSetRow> rows(WidgetTester tester) =>
      tester.widgetList<WorkoutSetRow>(find.byType(WorkoutSetRow)).toList();
  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> capture(
    WidgetTester tester, {
    String suffix = 'reverse-sets',
    bool top = false,
  }) async {
    if (!const bool.fromEnvironment('CAPTURE_SET_ORDER')) return;
    tester.view.physicalSize = top
        ? const Size(347, 1000)
        : const Size(432, 1900);
    await tester.pumpAndSettle();
    if (!top) await tester.ensureVisible(find.text('第 3 组'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final version = RegExp(
        r'^version:\s*([\d.]+)',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
      final file = File('artifacts/ui-redesign/$version-$suffix.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    tester.view.physicalSize = const Size(432, 1100);
    await tester.pumpAndSettle();
  }

  testWidgets('组倒序：新增与复制置顶，编辑/删除不串组且存储与完成顺序保留', (tester) async {
    final controller = await mount(tester);
    final original = controller.data.active!.exercises.first.sets;
    final ids = original.map((s) => s.id).toList();
    final originalJson = original.map((s) => s.toJson()).toList();
    expect(rows(tester).map((r) => r.set.id), ids.reversed);
    expect(rows(tester).map((r) => r.index), [2, 1, 0]);
    expect(
      tester.getTopLeft(row(ids[2])).dy,
      lessThan(tester.getTopLeft(row(ids[1])).dy),
    );
    await capture(tester);

    // Exercise the actual add button, not a controller-only list mutation.
    await tap(tester, find.text('新增一组'));
    var stored = controller.data.active!.exercises.first.sets;
    final addedId = stored.last.id;
    expect(rows(tester).first.set.id, addedId);
    expect(rows(tester).first.index, 3);
    expect(stored.take(3).map((s) => s.toJson()), originalJson);
    expect(tester.widget<TextField>(weight(addedId)).controller!.text, '');
    await tester.ensureVisible(weight(addedId));
    await tester.enterText(weight(addedId), '45');
    await tester.pumpAndSettle();
    expect(controller.data.active!.exercises.first.sets.last.weight, 45);
    expect(controller.data.active!.exercises.first.sets[2].weight, 30);

    // Copy the old middle row; the new row has a new ID but its own fields.
    await tap(
      tester,
      find.descendant(of: row(ids[1]), matching: find.byTooltip('复制本组为未完成组')),
    );
    stored = controller.data.active!.exercises.first.sets;
    final copiedId = stored.last.id;
    expect(copiedId, isNot(isIn([...ids, addedId])));
    expect(rows(tester).map((r) => r.set.id), [
      copiedId,
      addedId,
      ...ids.reversed,
    ]);
    expect(rows(tester).map((r) => r.index), [4, 3, 2, 1, 0]);
    expect(tester.widget<TextField>(weight(copiedId)).controller!.text, '20');
    expect(tester.widget<TextField>(weight(addedId)).controller!.text, '45');
    await tester.ensureVisible(weight(copiedId));
    await tester.enterText(weight(copiedId), '55');
    await tester.pumpAndSettle();
    expect(controller.data.active!.exercises.first.sets[1].weight, 20);
    expect(controller.data.active!.exercises.first.sets.last.weight, 55);
    await tap(
      tester,
      find.descendant(of: row(addedId), matching: find.byTooltip('删除本组')),
    );
    expect(rows(tester).map((r) => r.set.id), [copiedId, ...ids.reversed]);
    expect(tester.widget<TextField>(weight(copiedId)).controller!.text, '55');
    expect(tester.widget<TextField>(weight(ids[2])).controller!.text, '30');
    final raw = controller.data.active!.exercises.first.data['sets'] as List;
    expect(raw.map((s) => s['id']), [...ids, addedId, copiedId]);
    expect(raw.firstWhere((s) => s['id'] == addedId)['deleted'], true);

    await tap(tester, find.textContaining('完成下一组 ·'));
    stored = controller.data.active!.exercises.first.sets;
    expect(stored.where((s) => s.completed).single.id, ids.first);
    expect(rows(tester).first.set.id, copiedId);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('训练详情共享倒序展示，打开页面不改数据', (tester) async {
    final controller = await mount(tester, history: true);
    final stored = controller.data.sessions.single.exercises.first.sets;
    final before = controller.data.sessions.single.toJson();
    expect(rows(tester).map((r) => r.set.id), stored.reversed.map((s) => s.id));
    expect(rows(tester).map((r) => r.index), [2, 1, 0]);
    expect(controller.data.sessions.single.toJson(), before);
    expect(find.text('训练详情'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('紧凑统计与休息下方入口，多动作按ID添组/取消，新动作置顶', (tester) async {
    final controller = await mount(tester, multipleMoves: true);
    final originalMoves = controller.data.active!.exercises;
    final ids = originalMoves.map((m) => m.id).toList();
    Finder move(String id) => find.byKey(ValueKey('workout-move-$id'));
    final summary = find.byKey(const ValueKey('workout-summary'));
    final actions = find.byKey(const ValueKey('workout-add-actions'));
    expect(
      find.descendant(of: summary, matching: find.text('训练计时')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('实际完成')),
      findsOneWidget,
    );
    expect(tester.getSize(summary).height, lessThan(115));
    expect(
      tester.getTopLeft(find.text('训练计时')).dy,
      tester.getTopLeft(find.text('实际完成')).dy,
    );
    expect(
      tester.getTopLeft(find.text('新增一组')).dy,
      tester.getTopLeft(find.text('添加动作')).dy,
    );
    final rest = find.ancestor(
      of: find.text('组间休息'),
      matching: find.byType(Card),
    );
    expect(
      tester.getTopLeft(actions).dy,
      greaterThan(tester.getBottomLeft(rest).dy),
    );
    expect(
      tester.getBottomLeft(actions).dy,
      lessThan(tester.getTopLeft(move(ids.last)).dy),
    );
    expect(
      tester.getTopLeft(move(ids.last)).dy,
      lessThan(tester.getTopLeft(move(ids.first)).dy),
    );
    expect(find.text('新增一组'), findsOneWidget);
    await capture(tester, suffix: 'compact-training', top: true);

    await tap(tester, find.text('新增一组'));
    expect(find.text('给哪个动作新增一组？'), findsOneWidget);
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(controller.data.active!.exercises.map((m) => m.sets.length), [3, 1]);
    await tap(tester, find.text('新增一组'));
    await tap(tester, find.byKey(ValueKey('add-set-target-${ids.first}')));
    final added = controller.data.active!.exercises.first.sets.last;
    expect(controller.data.active!.exercises.map((m) => m.sets.length), [4, 1]);
    expect(
      tester
          .widgetList<WorkoutSetRow>(
            find.descendant(
              of: move(ids.first),
              matching: find.byType(WorkoutSetRow),
            ),
          )
          .first
          .set
          .id,
      added.id,
    );
    final preservedId = originalMoves.first.sets.first.id;
    final fieldController = tester
        .widget<TextField>(weight(preservedId))
        .controller;
    // Use the relocated picker to add an actual new move.
    await tap(tester, find.text('添加动作'));
    await tap(tester, find.text('杠铃卧推').last);
    final stored = controller.data.active!.exercises;
    expect(stored.take(2).map((m) => m.id), ids);
    expect(stored, hasLength(3));
    expect(
      tester.getTopLeft(move(stored.last.id)).dy,
      lessThan(tester.getTopLeft(move(ids.last)).dy),
    );
    expect(
      tester.widget<TextField>(weight(preservedId)).controller,
      same(fieldController),
    );
    final topUp = find.descendant(
      of: move(stored.last.id),
      matching: find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == '上移动作',
      ),
    );
    expect(tester.widget<IconButton>(topUp).onPressed, null);
    await tap(
      tester,
      find.descendant(of: move(ids.first), matching: find.byTooltip('上移动作')),
    );
    expect(
      tester.getTopLeft(move(ids.first)).dy,
      lessThan(tester.getTopLeft(move(ids.last)).dy),
    );
    expect(controller.data.active!.exercises.map((m) => m.id), [
      ids.last,
      ids.first,
      stored.last.id,
    ]);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('窄屏200%字体统计仍并排、入口自动换行无溢出', (tester) async {
    await mount(tester, textScale: 2);
    tester.view.physicalSize = const Size(320, 780);
    await tester.pumpAndSettle();
    final summaryContext = tester.element(
      find.byKey(const ValueKey('workout-summary')),
    );
    expect(MediaQuery.textScalerOf(summaryContext).scale(10), 20);
    expect(MediaQuery.sizeOf(summaryContext).width, 320);
    expect(
      tester.getTopLeft(find.text('训练计时')).dy,
      tester.getTopLeft(find.text('实际完成')).dy,
    );
    expect(
      tester.getTopLeft(find.text('添加动作')).dy,
      greaterThan(tester.getTopLeft(find.text('新增一组')).dy),
    );
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
