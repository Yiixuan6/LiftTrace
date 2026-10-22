import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lianji/application/controller.dart';
import 'package:lianji/data/repository.dart';
import 'package:lianji/domain/models.dart';
import 'package:lianji/main.dart';
import 'package:lianji/ui/components.dart';
import 'package:lianji/ui/statistics_page.dart';
import 'package:lianji/ui/theme.dart';
import 'statistics_presentation_test.dart' show statisticsFixture;

void main() {
  final now = DateTime(2026, 10, 20, 12);
  Future<void> render(
    WidgetTester tester,
    AppData data, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          controllerProvider.overrideWith(
            (ref) => AppController(MemoryTrainingRepository(data), data),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.build(BrandTheme.blue, Brightness.light),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(347, 780),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(body: StatisticsPage(now: now)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('概览不被动作选择改变；逐组曲线分口径、单点与辅助空态', (tester) async {
    final d = statisticsFixture(),
        raw = jsonEncode(statisticsFixture().settings);
    final before = jsonEncode(d.toJson());
    await render(tester, d);
    expect(find.text('640.0'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.text('动作趋势'));
    await tester.pumpAndSettle();
    Future<void> choose(String label) async {
      await tester.tap(find.byKey(const ValueKey('stats-exercise')));
      await tester.pumpAndSettle();
      if (find.text(label).evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.text(label),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text(label).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await choose('杠铃卧推 · 外部负重');
    expect(
      tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .lineBarsData
          .single
          .spots
          .length,
      2,
    );
    await choose('杠铃卧推 · 哑铃');
    expect(
      tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .lineBarsData
          .single
          .spots
          .length,
      1,
    );
    expect(find.textContaining('目前只有一组'), findsOneWidget);
    await choose('辅助引体向上 · 辅助器械');
    expect(find.byType(LineChart), findsNothing);
    expect(find.textContaining('此动作没有可计算'), findsOneWidget);
    await tester.tap(find.text('概览'));
    await tester.pumpAndSettle();
    expect(find.text('640.0'), findsOneWidget);
    expect(jsonEncode(d.toJson()), before);
    expect(jsonEncode(d.settings), raw);
  });
  testWidgets('七个周期入口、取消及大字体单列，无记录不假装成功', (tester) async {
    tester.view.physicalSize = const Size(347, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(tester, initialData(), scale: 2);
    expect(tester.takeException(), null);
    final cards = find.byType(StatCard);
    expect(cards, findsNWidgets(6));
    expect(
      tester.getTopLeft(cards.at(1)).dy,
      greaterThan(tester.getBottomLeft(cards.first).dy),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('stats-period')));
    await tester.tap(find.byKey(const ValueKey('stats-period')));
    await tester.pumpAndSettle();
    for (final label in ['最近 7 天', '最近 90 天', '本周', '本月', '本年', '全部时间']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.ensureVisible(find.text('本年'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本年'));
    await tester.pumpAndSettle();
    expect(find.text('时间范围'), findsNothing);
    expect(find.text('本年'), findsOneWidget);
    expect(tester.takeException(), null);
  });
  testWidgets('主选项卡往返保留周期、趋势分区与动作选择', (tester) async {
    tester.view.physicalSize = const Size(347, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final d = statisticsFixture();
    appRouter.go('/stats');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          controllerProvider.overrideWith(
            (ref) => AppController(MemoryTrainingRepository(d), d),
          ),
        ],
        child: const LianjiApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stats-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本年'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('动作趋势'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stats-exercise')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('杠铃卧推 · 外部负重').last);
    await tester.pumpAndSettle();
    for (final i in [1, 3, 2]) {
      await tester.tap(find.byKey(ValueKey('main-nav-$i')));
      await tester.pumpAndSettle();
    }
    expect(find.text('本年'), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<int>>(
            find.byKey(const ValueKey('stats-view')),
          )
          .selected,
      {1},
    );
    expect(find.text('杠铃卧推 · 外部负重'), findsOneWidget);
  });
  testWidgets('大量逐组节点完整保留并能横向浏览', (tester) async {
    tester.view.physicalSize = const Size(347, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final d = statisticsFixture(),
        move = statisticsFixture().sessions.first.exercises.first;
    for (var i = 0; i < 120; i++) {
      final set = WorkoutSet.empty();
      set.data.addAll({
        'weight': 20 + i % 5,
        'reps': 8,
        'completed': true,
        'completedAt': now
            .subtract(Duration(hours: 2, minutes: i))
            .toUtc()
            .toIso8601String(),
      });
      (move.data['sets'] as List).add(set.toJson());
    }
    // Keep the selected exercise ID from the actual fixture.
    d.sessions.first.exercises.first.data['sets'] = move.data['sets'];
    await render(tester, d);
    await tester.tap(find.text('动作趋势'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stats-exercise')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('杠铃卧推 · 外部负重').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .lineBarsData
          .single
          .spots
          .length,
      122,
    );
    await tester.ensureVisible(find.byType(LineChart));
    await tester.pumpAndSettle();
    final scroll = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    await tester.drag(scroll, const Offset(-600, 0));
    await tester.pumpAndSettle();
    final state = tester.state<ScrollableState>(
      find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
    );
    expect(state.position.pixels, greaterThan(0));
    expect(tester.takeException(), null);
  });
}
