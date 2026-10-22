import '../l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/controller.dart';
import '../domain/models.dart';
import 'components.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});
  @override
  ConsumerState<HistoryPage> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<HistoryPage> {
  DateTime? selected;
  String? exerciseId;
  bool calendar = false;
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    final list =
        c.data.sessions
            .where(
              (s) =>
                  !s.deleted &&
                  !s.active &&
                  (selected == null ||
                      dateKey(s.startedAt.toLocal()) == dateKey(selected!)) &&
                  (exerciseId == null ||
                      s.exercises.any(
                        (e) => e.data['exerciseId'] == exerciseId,
                      )),
            )
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return PageBody(
      title: tr(context, "训练历史"),
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: Text(tr(context, "日历")),
              selected: calendar,
              onSelected: (v) => setState(() => calendar = v),
            ),
            if (selected != null)
              InputChip(
                label: Text(dateKey(selected!)),
                onDeleted: () => setState(() => selected = null),
              ),
          ],
        ),
        if (calendar)
          CalendarDatePicker(
            initialDate: selected ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
            onDateChanged: (v) => setState(() => selected = v),
          ),
        DropdownButton<String?>(
          isExpanded: true,
          value: exerciseId,
          hint: Text(tr(context, "全部动作")),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(tr(context, "全部动作")),
            ),
            ...c.data.exercises
                .where((e) => !e.deleted)
                .map(
                  (e) => DropdownMenuItem<String?>(
                    value: e.id,
                    child: Text(e.name),
                  ),
                ),
          ],
          onChanged: (v) => setState(() => exerciseId = v),
        ),
        if (list.isEmpty) EmptyState(message: tr(context, "这里还没有训练记录")),
        ...list.map(
          (s) => WorkoutCard(
            title: s.title,
            subtitle: tr(context, "{0} · {1} 组 · {2} 分钟", [
              dateKey(s.startedAt.toLocal()),
              s.completedSets,
              s.duration(DateTime.now()).inMinutes,
            ]),
            onTap: () => context.push('/history/${s.id}'),
            trailing: IconButton(
              tooltip: tr(context, "删除训练"),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(
                      context,
                      tr(context, "删除这次训练？"),
                      tr(context, "删除后统计会同步更新。请先导出备份以便恢复。"),
                    ) &&
                    context.mounted) {
                  await runAction(
                    context,
                    () => c.change((d) {
                      final target = d.sessions.firstWhere((x) => x.id == s.id);
                      target.data['deleted'] = true;
                      target.touch();
                    }),
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
