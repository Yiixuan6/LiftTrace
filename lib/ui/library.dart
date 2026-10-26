import '../l10n/app_strings.dart';
import '../application/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models.dart';
import 'components.dart';

const muscles = ['胸', '背', '肩', '手臂', '腿', '全身'];
const kindLabels = ['总外部负重', '哑铃（单只重量）', '辅助重量', '有氧', '旧口径未明确'];
const kindShortLabels = ['外部负重', '哑铃', '辅助器械', '有氧', '未明确'];

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key, this.select});
  final ValueChanged<Exercise>? select;
  @override
  ConsumerState<LibraryPage> createState() => _LibraryState();
}

class _LibraryState extends ConsumerState<LibraryPage> {
  String query = '', muscle = '全部', equipment = '全部';
  bool favorites = false, recent = false;
  @override
  Widget build(BuildContext context) {
    final c = watchVisibleController(ref, context);
    final recentIds = c.data.sessions
        .where((s) => !s.deleted)
        .expand((s) => s.exercises)
        .map((e) => e.data['exerciseId'])
        .toSet();
    final list = c.data.exercises
        .where(
          (e) =>
              !e.deleted &&
              e.name.contains(query) &&
              (muscle == '全部' || e.muscle == muscle) &&
              (equipment == '全部' || e.equipment == equipment) &&
              (!favorites || e.favorite) &&
              (!recent || recentIds.contains(e.id)),
        )
        .toList();
    return PageBody(
      title: widget.select == null ? tr(context, "动作库") : tr(context, "添加动作"),
      children: [
        SearchBar(
          hintText: tr(context, "搜索动作名称"),
          leading: const Icon(Icons.search),
          onChanged: (v) => setState(() => query = v),
        ),
        Wrap(
          spacing: 8,
          children: ['全部', ...muscles]
              .map(
                (m) => FilterChip(
                  label: Text(tr(context, m)),
                  selected: muscle == m,
                  onSelected: (_) => setState(() => muscle = m),
                ),
              )
              .toList(),
        ),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: Text(tr(context, "收藏")),
              selected: favorites,
              onSelected: (v) => setState(() => favorites = v),
            ),
            FilterChip(
              label: Text(tr(context, "最近使用")),
              selected: recent,
              onSelected: (v) => setState(() => recent = v),
            ),
            DropdownButton<String>(
              value: equipment,
              items:
                  {
                        '全部',
                        ...c.data.exercises
                            .where((e) => !e.deleted)
                            .map((e) => e.equipment),
                      }
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(tr(context, v)),
                        ),
                      )
                      .toList(),
              onChanged: (v) => setState(() => equipment = v!),
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: () => createExercise(context, c),
          icon: const Icon(Icons.add),
          label: Text(tr(context, "自定义动作")),
        ),
        if (list.isEmpty) EmptyState(message: tr(context, "没有匹配动作，试试其他条件")),
        ...list.map(
          (e) => ExerciseCard(
            exercise: e,
            onTap: widget.select == null ? null : () => widget.select!(e),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: e.favorite ? tr(context, "取消收藏") : tr(context, "收藏"),
                  icon: Icon(e.favorite ? Icons.star : Icons.star_border),
                  onPressed: () => runAction(
                    context,
                    () => c.change((d) {
                      final target = d.exercises.firstWhere(
                        (x) => x.id == e.id,
                      );
                      target.data['favorite'] = !e.favorite;
                      target.touch();
                    }),
                  ),
                ),
                if (widget.select != null)
                  IconButton(
                    tooltip: tr(context, "添加 {0}", [e.name]),
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => widget.select!(e),
                  ),
                if (widget.select == null)
                  PopupMenuButton<String>(
                    tooltip: tr(context, "管理 {0}", [e.name]),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(tr(context, "编辑动作")),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(tr(context, "删除动作")),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await createExercise(context, c, existing: e);
                      } else if (await confirm(
                            context,
                            tr(context, "删除动作？"),
                            tr(context, "历史和模板中的快照保留。动作库将不再显示此动作。"),
                          ) &&
                          context.mounted) {
                        await runAction(
                          context,
                          () => c.change((d) {
                            final target = d.exercises.firstWhere(
                              (x) => x.id == e.id,
                            );
                            target.data['deleted'] = true;
                            target.touch();
                          }),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<Exercise?> pickExercise(BuildContext context) =>
    showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => SizedBox(
        height: MediaQuery.sizeOf(sheet).height * .88,
        child: LibraryPage(select: (e) => Navigator.pop(sheet, e)),
      ),
    );

Future<void> createExercise(
  BuildContext context,
  AppController c, {
  Exercise? existing,
}) async {
  final name = TextEditingController(text: existing?.name ?? ''),
      equipment = TextEditingController(text: existing?.equipment ?? '自定义');
  var muscle = existing?.muscle ?? '全身',
      kind = existing?.kind ?? LoadKind.external;
  String? error;
  final result = await showEditorialDialog<Exercise>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, refresh) => AlertDialog(
        title: Text(
          existing == null ? tr(context, "自定义动作") : tr(context, "编辑动作"),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LabeledTextField(controller: name, label: '动作名称'),
              const SizedBox(height: 12),
              LabeledTextField(controller: equipment, label: '器械'),
              DropdownButton<String>(
                isExpanded: true,
                value: muscle,
                items: {muscle, ...muscles}
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(tr(context, m)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => refresh(() => muscle = v!),
              ),
              DropdownButton<LoadKind>(
                isExpanded: true,
                value: kind,
                items: LoadKind.values
                    .where(
                      (k) => k != LoadKind.unknown || kind == LoadKind.unknown,
                    )
                    .map(
                      (k) => DropdownMenuItem(
                        value: k,
                        child: Text(kindShortLabels[k.index]),
                      ),
                    )
                    .toList(),
                onChanged: (v) => refresh(() => kind = v!),
              ),
              Text(kindLabels[kind.index]),
              if (error != null)
                Text(
                  tr(context, error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, "取消")),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty &&
                  equipment.text.trim().isNotEmpty) {
                Navigator.pop(
                  context,
                  Exercise.create(
                    name.text,
                    muscle,
                    equipment.text.trim(),
                    kind,
                  ),
                );
              } else {
                refresh(() => error = "请填写动作名称和器械");
              }
            },
            child: Text(
              existing == null ? tr(context, "创建") : tr(context, "保存"),
            ),
          ),
        ],
      ),
    ),
  );
  Future.delayed(const Duration(seconds: 1), () {
    name.dispose();
    equipment.dispose();
  });
  if (result != null) {
    await c.change((d) {
      if (existing == null) {
        d.exercises.add(result);
      } else {
        final target = d.exercises.firstWhere((e) => e.id == existing.id);
        target.data.addAll({
          'name': result.name,
          'muscle': result.muscle,
          'equipment': result.equipment,
          'kind': result.kind.name,
        });
        target.touch();
      }
    });
  }
}
