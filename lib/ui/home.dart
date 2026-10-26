import '../l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'components.dart';
import 'theme.dart';

export 'editorial_home.dart' show HomePage;

class TrainPage extends ConsumerWidget {
  const TrainPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = watchVisibleController(ref, context);
    return PageBody(
      root: true,
      title: tr(context, "训练"),
      subtitle: tr(context, "按自己的节奏，把努力慢慢积累。"),
      children: [
        SectionHeading(tr(context, "开始训练")),
        if (c.data.active != null)
          Text(
            tr(context, "{0} · {1} 组已保存", [
              c.data.active!.title,
              c.data.active!.completedSets,
            ]),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: ThemeTokens.homeActionColors(Theme.of(context)),
            ),
            borderRadius: BorderRadius.circular(40),
          ),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: () => runAction(context, () async {
              await c.start();
              if (context.mounted) context.go('/train/active');
            }),
            icon: const Icon(Icons.play_arrow),
            label: Text(
              c.data.active == null
                  ? tr(context, "自由训练 / 快速记录")
                  : tr(context, "继续当前训练"),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SectionHeading(tr(context, "训练工具")),
        MenuGroup(
          children: [
            ...[
              (
                tr(context, "动作库"),
                tr(context, "搜索、收藏、自定义与最近使用"),
                '/library',
                Icons.fitness_center,
              ),
              (
                tr(context, "训练模板"),
                tr(context, "胸、背、肩、手臂、腿和全身"),
                '/templates',
                Icons.view_agenda_outlined,
              ),
              (
                tr(context, "每周安排"),
                tr(context, "周一起始 · 每天按自己的节奏"),
                '/schedule',
                Icons.calendar_month,
              ),
              (
                tr(context, "训练历史"),
                tr(context, "日历、时间线与逐组详情"),
                '/history',
                Icons.history,
              ),
            ].map(
              (item) => ListTile(
                leading: Icon(item.$4),
                title: Text(item.$1),
                subtitle: Text(item.$2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(item.$3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
