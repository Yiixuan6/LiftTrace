import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/controller.dart';
import '../domain/models.dart';
import 'components.dart';

const bodyFields = [
  ('weight', '体重 kg'),
  ('waist', '腰围 cm'),
  ('chest', '胸围 cm'),
  ('hips', '臀围 cm'),
  ('arm', '上臂围 cm'),
  ('thigh', '大腿围 cm'),
];

class BodyPage extends ConsumerStatefulWidget {
  const BodyPage({super.key});
  @override
  ConsumerState<BodyPage> createState() => _BodyState();
}

class _BodyState extends ConsumerState<BodyPage> {
  String metric = 'weight';
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    final records = c.data.measurements.where((m) => !m.deleted).toList()
      ..sort(
        (a, b) =>
            (a.data['date'] as String).compareTo(b.data['date'] as String),
      );
    final points = records.where((m) => m.data[metric] != null).toList();
    return PageBody(
      title: '身体数据',
      subtitle: '围度可留空，缺失值不按零计算。',
      children: [
        FilledButton.icon(
          onPressed: () => editMeasurement(context, c),
          icon: const Icon(Icons.add),
          label: const Text('记录身体数据'),
        ),
        Wrap(
          spacing: 8,
          children: bodyFields
              .map(
                (p) => ChoiceChip(
                  label: Text(p.$2),
                  selected: metric == p.$1,
                  onSelected: (_) => setState(() => metric = p.$1),
                ),
              )
              .toList(),
        ),
        if (points.isNotEmpty)
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: points
                        .map(
                          (m) => FlSpot(
                            DateTime.parse(
                                  m.data['date'] as String,
                                ).millisecondsSinceEpoch /
                                86400000,
                            (m.data[metric] as num).toDouble(),
                          ),
                        )
                        .toList(),
                    isCurved: false,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        if (records.isEmpty) const EmptyState(message: '记录第一条身体数据，慢慢观察变化'),
        ...records.reversed.map(
          (m) => Card(
            child: ListTile(
              title: Text(m.data['date'] as String),
              subtitle: Text(
                bodyFields
                    .where((p) => m.data[p.$1] != null)
                    .map((p) => '${p.$2}：${m.data[p.$1]}')
                    .join('\n'),
              ),
              onTap: () => editMeasurement(context, c, existing: m),
              trailing: IconButton(
                tooltip: '删除身体记录',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(context, '删除这条身体记录？', '删除后趋势会更新。') &&
                      context.mounted) {
                    await runAction(
                      context,
                      () => c.change((d) {
                        final target = d.measurements.firstWhere(
                          (r) => r.id == m.id,
                        );
                        target.data['deleted'] = true;
                        target.touch();
                      }),
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> editMeasurement(
  BuildContext context,
  AppController c, {
  Record? existing,
}) async {
  existing ??= c.data.measurements
      .where((m) => !m.deleted && m.data['date'] == dateKey(DateTime.now()))
      .firstOrNull;
  final existingId = existing?.id;
  var date = existing == null
      ? DateTime.now()
      : DateTime.parse(existing.data['date'] as String);
  final fields = {
    for (final p in bodyFields)
      p.$1: TextEditingController(text: existing?.data[p.$1]?.toString() ?? ''),
  };
  String? error;
  final result = await showEditorialDialog<Json>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, refresh) => AlertDialog(
        title: const Text('身体数据'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (selected != null) refresh(() => date = selected);
                },
                child: Text(dateKey(date)),
              ),
              ...bodyFields.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LabeledTextField(
                    controller: fields[p.$1],
                    label: p.$2,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final values = <String, dynamic>{'date': dateKey(date)};
              if (c.data.measurements.any(
                (m) =>
                    !m.deleted &&
                    m.id != existingId &&
                    m.data['date'] == values['date'],
              )) {
                refresh(() => error = '当天已有记录，请编辑原记录');
                return;
              }
              for (final p in bodyFields) {
                final raw = fields[p.$1]!.text;
                final n = double.tryParse(raw);
                if (raw.isNotEmpty && (n == null || !n.isFinite || n <= 0)) {
                  refresh(() => error = '请填写大于 0 的数值，或留空');
                  return;
                }
                values[p.$1] = n;
              }
              if (bodyFields.every((p) => values[p.$1] == null)) {
                refresh(() => error = '至少填写一项');
                return;
              }
              Navigator.pop(context, values);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  Future.delayed(const Duration(seconds: 1), () {
    for (final f in fields.values) {
      f.dispose();
    }
  });
  if (result != null) {
    await c.change((d) {
      final target = existingId == null
          ? d.measurements
                .where((m) => !m.deleted && m.data['date'] == result['date'])
                .firstOrNull
          : d.measurements.firstWhere((m) => m.id == existingId);
      if (target == null) {
        d.measurements.add(Record({...Record.base(), ...result}));
      } else {
        target.data.addAll(result);
        target.touch();
      }
    });
  }
}
