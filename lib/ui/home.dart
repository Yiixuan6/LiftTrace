import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/controller.dart';
import 'components.dart';
import 'theme.dart';

export 'editorial_home.dart' show HomePage;

class TrainPage extends ConsumerWidget {
  const TrainPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    return PageBody(
      root: true,
      title: '训练',
      subtitle: '按自己的节奏，把努力慢慢积累。',
      children: [
        const SectionHeading('开始训练'),
        if (c.data.active != null)
          Text(
            '${c.data.active!.title} · ${c.data.active!.completedSets} 组已保存',
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
            label: Text(c.data.active == null ? '自由训练 / 快速记录' : '继续当前训练'),
          ),
        ),
        const SizedBox(height: 4),
        const SectionHeading('训练工具'),
        MenuGroup(
          children: [
            ...[
              ('动作库', '搜索、收藏、自定义与最近使用', '/library', Icons.fitness_center),
              (
                '训练模板',
                '胸、背、肩、手臂、腿和全身',
                '/templates',
                Icons.view_agenda_outlined,
              ),
              ('每周安排', '周一起始 · 每天按自己的节奏', '/schedule', Icons.calendar_month),
              ('训练历史', '日历、时间线与逐组详情', '/history', Icons.history),
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
