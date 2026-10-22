import '../l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'components.dart';

class WorkoutSetRow extends StatefulWidget {
  const WorkoutSetRow({
    super.key,
    required this.set,
    required this.kind,
    required this.index,
    required this.save,
    required this.complete,
    required this.remove,
    required this.copy,
    this.enabled = true,
    this.onValidityChanged,
  });
  final WorkoutSet set;
  final LoadKind kind;
  final int index;
  final Future<void> Function(Json) save;
  final Future<void> Function() complete, remove, copy;
  final bool enabled;
  final ValueChanged<bool>? onValidityChanged;
  @override
  State<WorkoutSetRow> createState() => _SetRowState();
}

class _SetRowState extends State<WorkoutSetRow> {
  final fields = <String, TextEditingController>{};
  bool busy = false;
  String? error;
  final invalidFields = <String>{};
  final versions = <String, int>{};
  @override
  void initState() {
    super.initState();
    for (final k in [
      'weight',
      'reps',
      'leftReps',
      'rightReps',
      'assistance',
      'seconds',
      'distance',
      'speed',
      'resistance',
      'note',
    ]) {
      fields[k] = TextEditingController(
        text: widget.set.data[k]?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> persist(String key, String value, {bool text = false}) async {
    final version = (versions[key] ?? 0) + 1;
    versions[key] = version;
    final num? parsed = text || value.isEmpty ? null : num.tryParse(value);
    if (!text &&
        value.isNotEmpty &&
        (parsed == null ||
            !parsed.isFinite ||
            parsed < 0 ||
            (key.toLowerCase().contains('reps') &&
                parsed != parsed.roundToDouble()))) {
      invalidFields.add(key);
      widget.onValidityChanged?.call(false);
      setState(() => error = "请填写有效的非负数，次数须为整数");
      return;
    }
    try {
      await widget.save({key: text ? (value.isEmpty ? null : value) : parsed});
      if (mounted && versions[key] == version) {
        invalidFields.remove(key);
        widget.onValidityChanged?.call(invalidFields.isEmpty);
        setState(() => error = invalidFields.isEmpty ? null : "仍有无效输入，请修正后再完成");
      }
    } catch (_) {
      if (mounted && versions[key] == version) {
        invalidFields.add(key);
        widget.onValidityChanged?.call(false);
        setState(() => error = "保存失败，请修正或重试后再完成");
      }
    }
  }

  Widget number(String key, String label) => SizedBox(
    width: MediaQuery.textScalerOf(
      context,
    ).scale(136).clamp(136, MediaQuery.sizeOf(context).width - 80),
    child: LabeledTextField(
      controller: fields[key],
      enabled: widget.enabled && !busy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
      label: label,
      onChanged: (v) => persist(key, v),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final d = widget.set.data;
    return Card(
      color: widget.set.completed
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  tr(context, "第 {0} 组{1}", [
                    widget.index + 1,
                    widget.set.completed ? tr(context, " · 已完成 ✓") : '',
                  ]),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  tooltip: tr(context, "复制本组为未完成组"),
                  onPressed: widget.enabled
                      ? () => runAction(context, widget.copy)
                      : null,
                  icon: const Icon(Icons.copy),
                ),
                IconButton(
                  tooltip: tr(context, "删除本组"),
                  onPressed: widget.enabled
                      ? () => runAction(context, widget.remove)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if ([
                  LoadKind.external,
                  LoadKind.dumbbell,
                  LoadKind.unknown,
                ].contains(widget.kind))
                  number(
                    'weight',
                    widget.kind == LoadKind.dumbbell ? '单只重量 kg' : '总外部重量 kg',
                  ),
                if (widget.kind == LoadKind.dumbbell) ...[
                  DropdownButton<String>(
                    isExpanded:
                        AppStrings.of(context).locale.languageCode == 'en' ||
                        MediaQuery.textScalerOf(context).scale(14) > 21,
                    itemHeight: null,
                    value: d['sideMode'] as String?,
                    hint: Text(tr(context, "单双侧方式")),
                    items: [
                      DropdownMenuItem(
                        value: 'bilateral',
                        child: Text(tr(context, "双侧")),
                      ),
                      DropdownMenuItem(
                        value: 'unilateral',
                        child: Text(tr(context, "单侧")),
                      ),
                    ],
                    onChanged: widget.enabled
                        ? (v) => runAction(
                            context,
                            () => widget.save({'sideMode': v}),
                          )
                        : null,
                  ),
                  number('leftReps', '左侧实际次数'),
                  number('rightReps', '右侧实际次数'),
                ] else if (widget.kind == LoadKind.cardio) ...[
                  number('seconds', '时长 秒'),
                  number('distance', '距离 km'),
                  number('speed', '速度 km/h'),
                  number('resistance', '阻力 / 档位'),
                ] else ...[
                  if (widget.kind == LoadKind.assisted)
                    number('assistance', '辅助重量 kg'),
                  number('reps', '次数'),
                ],
                if ([
                  LoadKind.external,
                  LoadKind.dumbbell,
                ].contains(widget.kind)) ...[
                  IconButton(
                    tooltip: tr(context, "重量减 2.5 kg"),
                    onPressed: !widget.enabled
                        ? null
                        : () {
                            final v =
                                ((num.tryParse(fields['weight']!.text) ?? 0) -
                                        2.5)
                                    .clamp(0, 100000);
                            fields['weight']!.text = '$v';
                            persist('weight', '$v');
                          },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  IconButton(
                    tooltip: tr(context, "重量加 2.5 kg"),
                    onPressed: !widget.enabled
                        ? null
                        : () {
                            final v =
                                (num.tryParse(fields['weight']!.text) ?? 0) +
                                2.5;
                            fields['weight']!.text = '$v';
                            persist('weight', '$v');
                          },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                DropdownButton<String>(
                  isExpanded:
                      AppStrings.of(context).locale.languageCode == 'en' ||
                      MediaQuery.textScalerOf(context).scale(14) > 21,
                  itemHeight: null,
                  value: d['feeling'] as String?,
                  hint: Text(tr(context, "感受（可选）")),
                  items: ['轻松', '适中', '吃力', '接近力竭']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(tr(context, v)),
                        ),
                      )
                      .toList(),
                  onChanged: widget.enabled
                      ? (v) => runAction(
                          context,
                          () => widget.save({'feeling': v}),
                        )
                      : null,
                ),
                DropdownButton<String>(
                  isExpanded:
                      AppStrings.of(context).locale.languageCode == 'en' ||
                      MediaQuery.textScalerOf(context).scale(14) > 21,
                  itemHeight: null,
                  value: d['bodyState'] as String?,
                  hint: Text(tr(context, "身体状态")),
                  items: ['无痛', '正常肌肉酸胀', '轻微不适', '明显疼痛']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(tr(context, v)),
                        ),
                      )
                      .toList(),
                  onChanged: widget.enabled
                      ? (v) => runAction(
                          context,
                          () => widget.save({'bodyState': v}),
                        )
                      : null,
                ),
              ],
            ),
            if (d['bodyState'] == '明显疼痛')
              Text(tr(context, "可以先放慢节奏或休息，留意身体感受。")),
            LabeledTextField(
              controller: fields['note'],
              enabled: widget.enabled,
              label: '逐组备注（可选）',
              maxLines: null,
              onChanged: (v) => persist('note', v, text: true),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  tr(context, error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            if (!widget.set.completed)
              FilledButton.icon(
                onPressed: !widget.enabled || busy
                    ? null
                    : () async {
                        if (error != null) return;
                        setState(() => busy = true);
                        try {
                          await widget.complete();
                        } catch (e) {
                          if (mounted) {
                            setState(
                              () => error = e is FormatException
                                  ? e.message
                                  : "保存失败，请重试",
                            );
                          }
                        }
                        if (mounted) setState(() => busy = false);
                      },
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(),
                      )
                    : const Icon(Icons.check),
                label: Text(tr(context, "完成当前组")),
              )
            else
              TextButton(
                onPressed: !widget.enabled
                    ? null
                    : () => runAction(
                        context,
                        () => widget.save({
                          'completed': false,
                          'completedAt': null,
                        }),
                      ),
                child: Text(tr(context, "撤销完成")),
              ),
          ],
        ),
      ),
    );
  }
}
