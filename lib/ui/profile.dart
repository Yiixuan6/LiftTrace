import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/controller.dart';
import '../domain/models.dart';
import 'components.dart';
import 'theme.dart';

const brandNames = ['活力橙', '冰川蓝', '鼠尾草绿'];
const appearanceNames = ['跟随系统', '浅色', '深色'];

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(controllerProvider);
    Widget destination(
      String title,
      String subtitle,
      String route,
      IconData icon,
    ) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
    return PageBody(
      root: true,
      title: '我的',
      subtitle: '属于你的训练，也属于你的数据。',
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline, size: 32),
            title: Text(c.data.settings['nickname'] as String? ?? '训练者'),
            subtitle: const Text('本地昵称 · 数据保存在这台设备上'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final value = await askText(
                context,
                '本地昵称',
                initial: c.data.settings['nickname'] as String? ?? '',
              );
              if (value != null) {
                await c.change((d) => d.settings['nickname'] = value);
              }
            },
          ),
        ),
        const SectionHeading('训练与外观偏好'),
        MenuGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('每周训练目标'),
              subtitle: Text('${c.data.settings['weeklyGoal'] ?? 3} 次'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final value = await askText(
                  context,
                  '每周目标次数（1–21）',
                  initial: '${c.data.settings['weeklyGoal'] ?? 3}',
                );
                final goal = int.tryParse(value ?? '');
                if (goal != null && goal > 0 && goal <= 21) {
                  await c.change((d) => d.settings['weeklyGoal'] = goal);
                }
              },
            ),
            destination('外观', '品牌与明暗模式', '/appearance', Icons.palette_outlined),
          ],
        ),
        const SectionHeading('身体与数据'),
        MenuGroup(
          children: [
            destination(
              '身体数据',
              '体重与围度',
              '/body',
              Icons.monitor_weight_outlined,
            ),
            destination(
              '备份与恢复',
              'JSON、CSV 和 WebDAV',
              '/backup',
              Icons.backup_outlined,
            ),
          ],
        ),
        const SectionHeading('关于'),
        MenuGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于练迹'),
              subtitle: const Text('0.2.10 · 个人离线训练日志'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: '练迹 · 训练日志',
                applicationVersion: '0.2.10',
                children: [
                  const Text(
                    '中文 · 公制 · 周一起始\n数据离线保存在本机，仅显式导出或配置 WebDAV 后传出。\n示例模板可自由修改，不构成个性化处方。',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final BrandTheme selected;
  final ValueChanged<BrandTheme> onSelected;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: BrandTheme.values
        .map(
          (brand) => SizedBox(
            width: 210,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: selected == brand
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: selected == brand ? 2 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => onSelected(brand),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        selected == brand
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: ThemeTokens.seeds[brand],
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        brandNames[brand.index],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(selected == brand ? '已选预览' : '查看预览'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
        .toList(),
  );
}

class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key});
  @override
  ConsumerState<AppearancePage> createState() => _AppearanceState();
}

class _AppearanceState extends ConsumerState<AppearancePage> {
  BrandTheme? previewBrand;
  Appearance? previewMode;
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(controllerProvider);
    final brand =
        previewBrand ??
        BrandTheme.values.byName(c.data.settings['brand'] as String);
    final mode =
        previewMode ??
        Appearance.values.byName(c.data.settings['appearance'] as String);
    final brightness = mode == Appearance.system
        ? MediaQuery.platformBrightnessOf(context)
        : mode == Appearance.dark
        ? Brightness.dark
        : Brightness.light;
    return PageBody(
      title: '外观',
      subtitle: '先预览，点击应用后保存。品牌与明暗模式独立设置。',
      children: [
        ThemeSelector(
          selected: brand,
          onSelected: (v) => setState(() => previewBrand = v),
        ),
        Wrap(
          spacing: 8,
          children: Appearance.values
              .map(
                (m) => ChoiceChip(
                  label: Text(appearanceNames[m.index]),
                  selected: mode == m,
                  onSelected: (_) => setState(() => previewMode = m),
                ),
              )
              .toList(),
        ),
        Theme(
          data: AppTheme.build(brand, brightness),
          child: Builder(
            builder: (context) => Card(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '下一组，继续积累',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const WorkoutCard(
                      title: '杠铃卧推',
                      subtitle: '40 kg · 8 次 · 第 2 组',
                      emphasis: true,
                    ),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('完成当前组 · 预览'),
                    ),
                    const SizedBox(height: 12),
                    const Text('当前只是局部预览'),
                  ],
                ),
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  await runAction(
                    context,
                    () => c.change((d) {
                      d.settings['brand'] = brand.name;
                      d.settings['appearance'] = mode.name;
                    }),
                  );
                  if (mounted) setState(() => busy = false);
                },
          child: Text(busy ? '保存中…' : '应用外观'),
        ),
      ],
    );
  }
}
