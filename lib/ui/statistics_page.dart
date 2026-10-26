import '../l10n/app_strings.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models.dart';
import '../domain/statistics.dart';
import 'components.dart';
import 'library.dart' show kindShortLabels;
import 'statistics_presentation.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key, this.now});
  final DateTime? now;
  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsState();
}

class _StatisticsState extends ConsumerState<StatisticsPage> {
  TimeFilter filter = TimeFilter.days30;
  int view = 0;
  String? selected;
  Future<void> choosePeriod() async {
    final value = await showModalBottomSheet<TimeFilter>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  tr(context, "时间范围"),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final f in TimeFilter.values)
                ListTile(
                  title: Text(tr(context, filterLabels[f.index])),
                  trailing: filter == f ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, f),
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null && mounted) setState(() => filter = value);
  }

  void explain() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(context, "统计口径"),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              tr(
                context,
                "仅已完成组计入组数与训练量，进行中训练的已完成组也会计入。训练次数仅计有有效完成记录的已结束训练，训练天数按完成日期去重。\n\n训练时长扣除显式暂停，正常组间休息保留。外部负重训练量为重量 × 次数；哑铃按单只重量 × 左右实际次数之和。辅助重量和有氧不并入外部负重训练量。\n\n动作趋势每个有效完成组一个点，按完成先后排列；同日各组保留，横轴并非等比例时间轴。总外部重量与哑铃单只重量分开展示。",
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final data = watchVisibleController(ref, context).data,
        now = widget.now ?? DateTime.now();
    final stats = Statistics.calculate(data, filter, now);
    final series = weightSeries(data, filter, now);
    final current = series.where((s) => s.key == selected).firstOrNull;
    return PageBody(
      root: true,
      title: tr(context, "统计"),
      subtitle: tr(context, "把每一次积累，看得更清楚。"),
      actions: [
        IconButton(
          tooltip: tr(context, "统计口径"),
          onPressed: explain,
          icon: const Icon(Icons.info_outline),
        ),
      ],
      children: [
        OutlinedButton.icon(
          key: const ValueKey('stats-period'),
          onPressed: choosePeriod,
          icon: const Icon(Icons.date_range_outlined),
          label: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(tr(context, filterLabels[filter.index])),
              const Icon(Icons.expand_more, size: 20),
            ],
          ),
        ),
        SegmentedButton<int>(
          key: const ValueKey('stats-view'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 0, label: Text(tr(context, "概览"))),
            ButtonSegment(value: 1, label: Text(tr(context, "动作趋势"))),
          ],
          selected: {view},
          onSelectionChanged: (v) => setState(() => view = v.single),
        ),
        if (view == 0) ...[
          SectionHeading(tr(context, "训练概览")),
          _Metrics(stats),
          SectionHeading(tr(context, "外部负重训练量")),
          _VolumeChart(
            buckets: volumeBuckets(stats.dailyVolume, filter),
            filter: filter,
          ),
          SectionHeading(tr(context, "肌群分布")),
          _Muscles(stats.muscles),
        ] else ...[
          SectionHeading(tr(context, "逐组重量趋势")),
          FieldCaption(
            label: tr(context, "选择动作"),
            child: DropdownButtonFormField<String>(
              key: const ValueKey('stats-exercise'),
              initialValue: current?.key,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.fitness_center),
              ),
              items: series
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.key,
                      child: Text(
                        '${s.name} · ${tr(context, kindShortLabels[s.kind.index])}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => selected = v),
            ),
          ),
          if (current == null)
            ContentPanel(
              child: EmptyState(message: tr(context, "选择一个动作，查看每一组的重量变化")),
            )
          else if (!current.supportsWeight)
            ContentPanel(
              child: EmptyState(
                message: tr(context, "此动作没有可计算的负重趋势，辅助重量与有氧不并入重量曲线"),
              ),
            )
          else if (current.points.isEmpty)
            ContentPanel(
              child: EmptyState(message: tr(context, "所选时间内暂无已完成的重量记录")),
            )
          else
            _WeightChart(series: current),
        ],
      ],
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics(this.stats);
  final Statistics stats;
  @override
  Widget build(BuildContext context) {
    final values = [
      (tr(context, "训练次数"), '${stats.sessions}', tr(context, "次")),
      (
        tr(context, "外部负重训练量"),
        stats.volume.toStringAsFixed(1),
        tr(context, "kg·次"),
      ),
      (tr(context, "训练时长"), '${stats.duration.inMinutes}', tr(context, "分钟")),
      (tr(context, "完成组数"), '${stats.sets}', tr(context, "组")),
      (tr(context, "训练天数"), '${stats.days.length}', tr(context, "天")),
      (
        tr(context, "有氧时长"),
        (stats.cardioSeconds / 60).toStringAsFixed(1),
        tr(context, "分钟"),
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
        final columns = largeText || box.maxWidth < 270
            ? 1
            : box.maxWidth >= 650
            ? 3
            : 2;
        return Column(
          key: const ValueKey('stats-metrics'),
          children: [
            for (var start = 0; start < values.length; start += columns) ...[
              if (start > 0) const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var i = start;
                      i < math.min(start + columns, values.length);
                      i++
                    ) ...[
                      if (i > start) const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: values[i].$1,
                          value: values[i].$2,
                          unit: values[i].$3,
                          fluid: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

String _date(DateTime at, {bool month = false}) =>
    month ? '${at.year}/${at.month}' : '${at.month}/${at.day}';
String _number(double n) => n.abs() >= 1000000
    ? '${(n / 1000000).toStringAsFixed(1)}m'
    : n.abs() >= 1000
    ? '${(n / 1000).toStringAsFixed(1)}k'
    : n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1);
AxisTitles _leftTitles() => AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 48,
    getTitlesWidget: (v, meta) =>
        Text(_number(v), style: const TextStyle(fontSize: 11)),
  ),
);
FlGridData _grid(BuildContext context) => FlGridData(
  show: true,
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) => FlLine(
    color: Theme.of(context).colorScheme.outlineVariant,
    strokeWidth: .6,
  ),
);

class _VolumeChart extends StatelessWidget {
  const _VolumeChart({required this.buckets, required this.filter});
  final List<VolumeBucket> buckets;
  final TimeFilter filter;
  @override
  Widget build(BuildContext context) {
    final month = filter == TimeFilter.year || filter == TimeFilter.all;
    final scope = month
        ? tr(context, "每月")
        : filter == TimeFilter.days90
        ? tr(context, "每周（周一起始）")
        : tr(context, "每日");
    final colors = Theme.of(context).colorScheme;
    return ContentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, "{0} · kg·次", [scope]),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (buckets.isEmpty)
            EmptyState(message: tr(context, "完成第一组负重训练后，训练量会在这里出现"))
          else ...[
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, box) {
                final width = math.max(
                  box.maxWidth,
                  64 + buckets.length * 42.0,
                );
                return Semantics(
                  label: tr(context, "外部负重训练量柱状图，可横向滚动，点按查看日期和数值"),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      height: 230 + MediaQuery.textScalerOf(context).scale(12),
                      child: BarChart(
                        BarChartData(
                          minY: 0,
                          maxY: math.max(
                            1,
                            buckets.map((b) => b.volume).reduce(math.max) * 1.2,
                          ),
                          barGroups: buckets.indexed
                              .map(
                                (p) => BarChartGroupData(
                                  x: p.$1,
                                  barRods: [
                                    BarChartRodData(
                                      toY: p.$2.volume,
                                      color: colors.primary,
                                      width: 14,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                          titlesData: FlTitlesData(
                            leftTitles: _leftTitles(),
                            topTitles: const AxisTitles(),
                            rightTitles: const AxisTitles(),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 44,
                                getTitlesWidget: (v, meta) {
                                  final i = v.toInt();
                                  if (i < 0 ||
                                      i >= buckets.length ||
                                      v != i.toDouble()) {
                                    return const SizedBox.shrink();
                                  }
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: Text(
                                      _date(buckets[i].date, month: month),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          gridData: _grid(context),
                          borderData: FlBorderData(show: false),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              fitInsideHorizontally: true,
                              fitInsideVertically: true,
                              getTooltipColor: (_) => colors.inverseSurface,
                              getTooltipItem:
                                  (group, groupIndex, rod, rodIndex) =>
                                      BarTooltipItem(
                                        tr(context, "{0}\n{1} kg·次", [
                                          dateKey(buckets[group.x].date),
                                          rod.toY.toStringAsFixed(1),
                                        ]),
                                        TextStyle(
                                          color: colors.onInverseSurface,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Text(
              tr(context, "点按柱形查看数值 · 记录较多时可左右滑动"),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(tr(context, "训练量明细")),
              children: [
                for (final b in buckets)
                  _DetailLine(
                    dateKey(b.date),
                    tr(context, "{0} kg·次", [b.volume.toStringAsFixed(1)]),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Muscles extends StatelessWidget {
  const _Muscles(this.values);
  final Map<String, int> values;
  @override
  Widget build(BuildContext context) {
    final list = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = values.values.fold(0, (a, b) => a + b);
    return ContentPanel(
      child: list.isEmpty
          ? EmptyState(message: tr(context, "暂无已完成组"))
          : Column(
              children: [
                for (final e in list)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        _DetailLine(
                          tr(context, e.key),
                          tr(context, "{0} 组", [e.value]),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: 7,
                            value: e.value / total,
                            semanticsLabel: tr(context, "{0}，{1}组，共{2}组", [
                              e.key,
                              e.value,
                              total,
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.series});
  final WeightSeries series;
  @override
  Widget build(BuildContext context) {
    final points = series.points, colors = Theme.of(context).colorScheme;
    final single = points.length == 1;
    return ContentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, series.unitLabel),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            single
                ? tr(context, "目前只有一组记录，继续积累后会连成趋势。")
                : tr(context, "{0} 条已完成组 · 按完成先后排列", [points.length]),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, box) => Semantics(
              label: tr(context, "逐组重量折线图，每组一个点，可横向滚动，点按查看完成时间和重量"),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(box.maxWidth, 64 + points.length * 42.0),
                  height: 230 + MediaQuery.textScalerOf(context).scale(12),
                  child: LineChart(
                    LineChartData(
                      minX: single ? -.5 : 0,
                      maxX: single ? .5 : (points.length - 1).toDouble(),
                      minY: 0,
                      maxY: math.max(
                        1,
                        points.map((p) => p.weight).reduce(math.max) * 1.2,
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: points.indexed
                              .map((p) => FlSpot(p.$1.toDouble(), p.$2.weight))
                              .toList(),
                          isCurved: false,
                          color: colors.primary,
                          barWidth: 2,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                      gridData: _grid(context),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: _leftTitles(),
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: 44,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 ||
                                  i >= points.length ||
                                  v != i.toDouble()) {
                                return const SizedBox.shrink();
                              }
                              if (i > 0 &&
                                  dateKey(points[i].at.toLocal()) ==
                                      dateKey(points[i - 1].at.toLocal())) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  _date(points[i].at.toLocal()),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipColor: (_) => colors.inverseSurface,
                          getTooltipItems: (spots) => spots.map((spot) {
                            final p = points[spot.spotIndex],
                                at = p.at.toLocal();
                            final time =
                                '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
                            return LineTooltipItem(
                              '${dateKey(at)} $time\n${p.weight} kg',
                              TextStyle(color: colors.onInverseSurface),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(context, "每组一个点 · 点按查看详情 · 可左右滑动"),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(tr(context, "逐组明细")),
            children: [
              for (final p in points)
                _DetailLine(
                  '${dateKey(p.at.toLocal())} ${TimeOfDay.fromDateTime(p.at.toLocal()).format(context)}',
                  '${p.weight} kg',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(label),
        Text(value, style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}
