import '../l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/controller.dart';
import '../domain/models.dart';
import 'components.dart';
import 'library.dart';

class TemplatesPage extends ConsumerWidget {
  const TemplatesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = watchVisibleController(ref, context);
    return PageBody(
      title: tr(context, "训练模板"),
      subtitle: tr(context, "示例可编辑，仅作记录结构参考，不是个性化训练处方。"),
      children: [
        FilledButton.icon(
          onPressed: () => context.push('/templates/new'),
          icon: const Icon(Icons.add),
          label: Text(tr(context, "创建模板")),
        ),
        ...c.data.templates
            .where((t) => !t.deleted)
            .map(
              (t) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        t.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        tr(context, "{0} 个动作", [
                          (t.data['exercises'] as List).length,
                        ]),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => runAction(context, () async {
                              await c.start(template: t);
                              if (context.mounted) context.go('/train/active');
                            }),
                            child: Text(
                              c.data.active == null
                                  ? tr(context, "开始")
                                  : tr(context, "继续已有训练"),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/templates/${t.id}'),
                            child: Text(tr(context, "编辑")),
                          ),
                          TextButton(
                            onPressed: () => runAction(
                              context,
                              () => c.change(
                                (d) => d.templates.add(
                                  WorkoutTemplate.create(
                                    tr(context, "{0} 副本", [t.name]),
                                    t.freshExercises(),
                                  ),
                                ),
                              ),
                            ),
                            child: Text(tr(context, "复制")),
                          ),
                          TextButton(
                            onPressed: () async {
                              if (await confirm(
                                    context,
                                    tr(context, "删除模板？"),
                                    tr(context, "已有历史快照不受影响，对应周安排将设为空。"),
                                  ) &&
                                  context.mounted) {
                                await runAction(
                                  context,
                                  () => c.change((d) {
                                    final target = d.templates.firstWhere(
                                      (x) => x.id == t.id,
                                    );
                                    target.data['deleted'] = true;
                                    target.touch();
                                    d.schedule.removeWhere((k, v) => v == t.id);
                                  }),
                                );
                              }
                            },
                            child: Text(tr(context, "删除")),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class TemplateEditor extends ConsumerStatefulWidget {
  const TemplateEditor({super.key, required this.id});
  final String id;
  @override
  ConsumerState<TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends ConsumerState<TemplateEditor> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  List<WorkoutExercise> moves = [];
  bool initialized = false, busy = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final template = ref
        .read(controllerProvider)
        .data
        .templates
        .where((t) => t.id == widget.id && !t.deleted)
        .firstOrNull;
    if (template != null) {
      name.text = template.name;
      moves = template.freshExercises();
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: PageBody(
      title: widget.id == 'new' ? tr(context, "创建模板") : tr(context, "编辑模板"),
      children: [
        LabeledTextField(controller: name, label: '模板名称'),
        ...moves.indexed.map((pair) {
          final i = pair.$1,
              e = pair.$2,
              target = e.sets.firstOrNull ?? WorkoutSet.empty();
          return Card(
            key: ValueKey(e.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    e.exercise.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  FieldGrid(
                    children: [
                      SizedBox(
                        width: MediaQuery.textScalerOf(
                          context,
                        ).scale(140).clamp(140, 260),
                        child: LabeledTextField(
                          formField: true,
                          initialValue: '${e.sets.length}',
                          label: '目标组数',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return n == null || n < 1 || n > 100
                                ? tr(context, "请输入 1–100 组")
                                : null;
                          },
                          onChanged: (v) {
                            final count = int.tryParse(v);
                            if (count != null && count > 0 && count <= 100) {
                              final current =
                                  e.sets.firstOrNull ?? WorkoutSet.empty();
                              e.data['sets'] = List.generate(
                                count,
                                (_) => current.duplicate().toJson(),
                              );
                            }
                          },
                        ),
                      ),
                      ...[
                        ('reps', '目标次数'),
                        (
                          'weight',
                          e.exercise.kind == LoadKind.dumbbell
                              ? '单只重量 kg'
                              : '参考重量 kg',
                        ),
                        ('seconds', '目标时长 秒'),
                      ].map(
                        (p) => SizedBox(
                          width: MediaQuery.textScalerOf(
                            context,
                          ).scale(140).clamp(140, 260),
                          child: LabeledTextField(
                            formField: true,
                            initialValue: target.data[p.$1]?.toString() ?? '',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            label: p.$2,
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final n = num.tryParse(v);
                              return n == null ||
                                      !n.isFinite ||
                                      n < 0 ||
                                      (p.$1 == 'reps' && n != n.roundToDouble())
                                  ? tr(context, "请输入有效数值")
                                  : null;
                            },
                            onChanged: (v) {
                              final n = num.tryParse(v);
                              if (v.isEmpty ||
                                  (n != null && n.isFinite && n >= 0)) {
                                for (final s in e.sets) {
                                  s.data[p.$1] = n;
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.textScalerOf(
                          context,
                        ).scale(140).clamp(140, 260),
                        child: LabeledTextField(
                          formField: true,
                          initialValue: '${e.data['restSeconds'] ?? 90}',
                          label: '休息 秒',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return n == null || n < 1 || n > 86400
                                ? tr(context, "请输入 1–86400 秒")
                                : null;
                          },
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n > 0 && n <= 86400) {
                              e.data['restSeconds'] = n;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    children: [
                      IconButton(
                        tooltip: tr(context, "上移动作"),
                        onPressed: i == 0
                            ? null
                            : () => setState(() {
                                moves.removeAt(i);
                                moves.insert(i - 1, e);
                              }),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: tr(context, "删除动作"),
                        onPressed: () => setState(() => moves.removeAt(i)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () async {
            final e = await pickExercise(context);
            if (e != null) {
              setState(() => moves.add(WorkoutExercise.fromExercise(e)));
            }
          },
          icon: const Icon(Icons.add),
          label: Text(tr(context, "添加动作")),
        ),
        if (error != null) ErrorState(message: error!),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  if (name.text.trim().isEmpty || moves.isEmpty) {
                    setState(() => error = "请填写名称并添加至少一个动作");
                    return;
                  }
                  setState(() => busy = true);
                  try {
                    await ref.read(controllerProvider).change((d) {
                      final existing = d.templates
                          .where((t) => t.id == widget.id)
                          .firstOrNull;
                      if (existing == null) {
                        d.templates.add(
                          WorkoutTemplate.create(name.text.trim(), moves),
                        );
                      } else {
                        existing.data.addAll({
                          'name': name.text.trim(),
                          'exercises': moves.map((e) => e.toJson()).toList(),
                        });
                        existing.touch();
                      }
                    });
                    if (context.mounted) context.pop();
                  } catch (_) {
                    if (mounted) setState(() => error = "保存失败，请重试");
                  }
                  if (mounted) setState(() => busy = false);
                },
          child: Text(busy ? tr(context, "保存中…") : tr(context, "保存模板")),
        ),
      ],
    ),
  );
}

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = watchVisibleController(ref, context),
        templates = c.data.templates.where((t) => !t.deleted).toList();
    return PageBody(
      title: tr(context, "每周安排"),
      subtitle: tr(context, "每周从星期一开始。选择休息日或一个模板。"),
      children: List.generate(
        7,
        (i) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.of(context).weekday(i + 1),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value:
                      templates.any((t) => t.id == c.data.schedule['${i + 1}'])
                      ? c.data.schedule['${i + 1}'] as String
                      : 'rest',
                  items: [
                    DropdownMenuItem(
                      value: 'rest',
                      child: Text(tr(context, "休息日")),
                    ),
                    ...templates.map(
                      (t) => DropdownMenuItem(value: t.id, child: Text(t.name)),
                    ),
                  ],
                  onChanged: (v) => runAction(
                    context,
                    () => c.change((d) => d.schedule['${i + 1}'] = v),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
