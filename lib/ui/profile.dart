import '../l10n/app_strings.dart';
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
    final c = watchVisibleController(ref, context);
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
      title: tr(context, "我的"),
      subtitle: tr(context, "属于你的训练，也属于你的数据。"),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline, size: 32),
            title: Text(
              c.data.settings['nickname'] as String? ?? tr(context, "训练者"),
            ),
            subtitle: Text(tr(context, "本地昵称 · 数据保存在这台设备上")),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final value = await askText(
                context,
                tr(context, "本地昵称"),
                initial: c.data.settings['nickname'] as String? ?? '',
              );
              if (value != null) {
                await c.change((d) => d.settings['nickname'] = value);
              }
            },
          ),
        ),
        SectionHeading(tr(context, "训练与外观偏好")),
        MenuGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(tr(context, "每周训练目标")),
              subtitle: Text(
                tr(context, "{0} 次", [c.data.settings['weeklyGoal'] ?? 3]),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final value = await askText(
                  context,
                  tr(context, "每周目标次数（1–21）"),
                  initial: '${c.data.settings['weeklyGoal'] ?? 3}',
                );
                final goal = int.tryParse(value ?? '');
                if (goal != null && goal > 0 && goal <= 21) {
                  await c.change((d) => d.settings['weeklyGoal'] = goal);
                }
              },
            ),
            ListTile(
              key: const ValueKey('language-settings'),
              leading: const Icon(Icons.language_outlined),
              title: Text(tr(context, '语言')),
              subtitle: Text(
                languageName(context, c.data.settings['language'] as String?),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => chooseLanguage(context, c),
            ),
            destination(
              tr(context, "外观"),
              tr(context, "品牌与明暗模式"),
              '/appearance',
              Icons.palette_outlined,
            ),
          ],
        ),
        SectionHeading(tr(context, "身体与数据")),
        MenuGroup(
          children: [
            destination(
              tr(context, "身体数据"),
              tr(context, "体重与围度"),
              '/body',
              Icons.monitor_weight_outlined,
            ),
            destination(
              tr(context, "备份与恢复"),
              tr(context, "JSON、CSV 和 WebDAV"),
              '/backup',
              Icons.backup_outlined,
            ),
          ],
        ),
        SectionHeading(tr(context, "关于")),
        MenuGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(tr(context, "关于练迹")),
              subtitle: Text(tr(context, "0.2.12 · 个人离线训练日志")),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: tr(context, "练迹 · 训练日志"),
                applicationVersion: '0.2.12',
                children: [
                  Text(
                    tr(
                      context,
                      "中文 · 公制 · 周一起始\n数据离线保存在本机，仅显式导出或配置 WebDAV 后传出。\n示例模板可自由修改，不构成个性化处方。",
                    ),
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
                        tr(context, brandNames[brand.index]),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        selected == brand
                            ? tr(context, "已选预览")
                            : tr(context, "查看预览"),
                      ),
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
    final c = watchVisibleController(ref, context);
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
      title: tr(context, "外观"),
      subtitle: tr(context, "先预览，点击应用后保存。品牌与明暗模式独立设置。"),
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
                  label: Text(tr(context, appearanceNames[m.index])),
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
                      tr(context, "下一组，继续积累"),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    WorkoutCard(
                      title: tr(context, "杠铃卧推"),
                      subtitle: tr(context, "40 kg · 8 次 · 第 2 组"),
                      emphasis: true,
                    ),
                    FilledButton(
                      onPressed: () {},
                      child: Text(tr(context, "完成当前组 · 预览")),
                    ),
                    const SizedBox(height: 12),
                    Text(tr(context, "当前只是局部预览")),
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
          child: Text(busy ? tr(context, "保存中…") : tr(context, "应用外观")),
        ),
      ],
    );
  }
}

String languageName(BuildContext context, String? code) => switch (code) {
  'system' => tr(context, '跟随系统'),
  'zh_Hant' => '繁體中文',
  'en' => 'English',
  _ => '简体中文',
};

Future<void> chooseLanguage(
  BuildContext context,
  AppController controller,
) async {
  final selected = controller.data.settings['language'] as String? ?? 'zh_Hans';
  final value = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                tr(context, '应用语言'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(tr(context, '界面与提醒语言；训练名称和备注保留原文')),
            ),
            for (final code in AppStrings.preferences)
              ListTile(
                key: ValueKey('language-$code'),
                title: Text(languageName(context, code)),
                subtitle: code == 'system'
                    ? Text(tr(context, '将使用设备语言，不支持的语言使用简体中文'))
                    : null,
                trailing: selected == code ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, code),
              ),
          ],
        ),
      ),
    ),
  );
  if (value == null || value == selected || !context.mounted) return;
  await runAction(
    context,
    () => controller.change((data) => data.settings['language'] = value),
  );
}
