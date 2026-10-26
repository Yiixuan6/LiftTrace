import '../l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/models.dart';
import '../domain/statistics.dart';
import 'components.dart';
import 'theme.dart';

/// Real records only. The optional clock is for deterministic visual evidence.
class HomePage extends ConsumerWidget {
  const HomePage({super.key, this.now});
  final DateTime? now;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = watchVisibleController(ref, context), d = c.data;
    final at = now ?? DateTime.now();
    final week = Statistics.calculate(d, TimeFilter.week, at);
    final all = Statistics.calculate(d, TimeFilter.all, at);
    final active = d.active;
    final today = d.templates
        .where((t) => !t.deleted && t.id == d.schedule['${at.weekday}'])
        .firstOrNull;
    final restDay = d.schedule['${at.weekday}'] == 'rest';
    final history = d.sessions.where((s) => !s.deleted && !s.active).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final goal = (d.settings['weeklyGoal'] as num?)?.toInt() ?? 3;
    final recentSessions = d.sessions.where((s) => !s.deleted).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final recentIds = recentSessions
        .expand((s) => s.exercises)
        .map((e) => e.data['exerciseId'])
        .toSet()
        .take(4);
    final colors = Theme.of(context).colorScheme;
    final planTitle =
        active?.title ??
        today?.name ??
        (restDay ? tr(context, "今天是休息日") : tr(context, "自由训练"));
    final planSubtitle = active != null
        ? tr(context, "{0} 组已保存 · 随时继续", [active.completedSets])
        : today != null
        ? tr(context, "{0} 个动作 · 按自己的节奏开始", [
            today.data['exercises'] is List
                ? (today.data['exercises'] as List).length
                : 0,
          ])
        : restDay
        ? tr(context, "放松一下，也可以自由记录")
        : tr(context, "不必等计划准备好，随时开始");
    return Material(
      color: Colors.transparent,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HomeHero(at: at),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          EditorialSectionTitle(
                            active == null
                                ? tr(context, "今日训练")
                                : tr(context, "训练进行中"),
                          ),
                          const SizedBox(height: 12),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => context.push(
                                active != null
                                    ? '/train/active'
                                    : today != null
                                    ? '/templates/${today.id}'
                                    : '/train',
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    _WorkoutIcon(
                                      icon: active == null
                                          ? null
                                          : Icons.play_arrow_rounded,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            planTitle,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            planSubtitle,
                                            style: TextStyle(
                                              color: colors.onSurfaceVariant,
                                              fontSize: 14,
                                              height: 1.45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: colors.outline,
                                      size: 23,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(80),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: ThemeTokens.homeActionColors(
                                  Theme.of(context),
                                ),
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .55),
                                width: .8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: ThemeTokens.homeActionColors(
                                    Theme.of(context),
                                  ).last.withValues(alpha: .24),
                                  blurRadius: 22,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 9),
                                ),
                              ],
                            ),
                            child: FilledButton.icon(
                              key: const ValueKey('home-start-workout'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                surfaceTintColor: Colors.transparent,
                                foregroundColor: colors.onPrimary,
                                minimumSize: const Size(48, 56),
                                shape: const StadiumBorder(),
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              onPressed: () => runAction(context, () async {
                                await c.start(template: today);
                                if (context.mounted) {
                                  context.go('/train/active');
                                }
                              }),
                              icon: Icon(
                                active == null
                                    ? Icons.play_arrow_rounded
                                    : Icons.arrow_forward,
                                size: 27,
                              ),
                              label: Text(
                                active == null
                                    ? tr(context, "开始训练")
                                    : tr(context, "继续训练"),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          EditorialSectionTitle(tr(context, "本周目标")),
                          const SizedBox(height: 10),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            spacing: 8,
                            children: [
                              Text(
                                '${week.sessions}',
                                style: TextStyle(
                                  fontSize: 40,
                                  height: 1.1,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  tr(context, "/ {0} 次", [goal]),
                                  style: TextStyle(
                                    fontSize: 23,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: ColoredBox(
                              color: colors.primary.withValues(alpha: .09),
                              child: ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    colors.primary,
                                    ThemeTokens.glassRim.first,
                                  ],
                                  stops: [
                                    0,
                                    goal > 0
                                        ? (week.sessions / goal).clamp(.001, 1)
                                        : 1,
                                  ],
                                ).createShader(bounds),
                                child: LinearProgressIndicator(
                                  minHeight: 11,
                                  value: goal > 0
                                      ? (week.sessions / goal).clamp(0, 1)
                                      : 0,
                                  color: Colors.white,
                                  backgroundColor: Colors.transparent,
                                  semanticsLabel: tr(
                                    context,
                                    "本周训练进度，已完成{0}次，目标{1}次",
                                    [week.sessions, goal],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Divider(
                            height: 1,
                            color: colors.outlineVariant.withValues(alpha: .6),
                          ),
                          const SizedBox(height: 10),
                          EditorialSectionTitle(tr(context, "最近训练")),
                          const SizedBox(height: 8),
                          if (history.isEmpty)
                            _RecentTrainingRow(
                              title: tr(context, "从第一次记录开始"),
                              subtitle: tr(context, "训练结束后，这里会留下你的足迹"),
                              onTap: () => context.push('/history'),
                            )
                          else
                            _RecentTrainingRow(
                              title: tr(context, "{0}月{1}日 · {2} · {3}分钟", [
                                history.first.startedAt.toLocal().month,
                                history.first.startedAt.toLocal().day,
                                history.first.title,
                                history.first.duration(at).inMinutes,
                              ]),
                              onTap: () =>
                                  context.push('/history/${history.first.id}'),
                            ),
                          const SizedBox(height: 48),
                          Divider(
                            height: 1,
                            color: colors.outlineVariant.withValues(alpha: .6),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 20,
                            runSpacing: 12,
                            children: [
                              _QuietMetric(
                                value: '${all.duration.inMinutes}',
                                label: tr(context, "累计分钟"),
                              ),
                              _QuietMetric(
                                value: '${all.sets}',
                                label: tr(context, "累计完成组"),
                              ),
                              TextButton.icon(
                                onPressed: () => context.push('/history'),
                                icon: const Icon(Icons.history, size: 20),
                                label: Text(tr(context, "训练历史")),
                              ),
                            ],
                          ),
                          if (recentIds.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            EditorialSectionTitle(tr(context, "最近动作")),
                            const SizedBox(height: 12),
                            ...recentIds
                                .map(
                                  (id) => d.exercises
                                      .where((e) => e.id == id && !e.deleted)
                                      .firstOrNull,
                                )
                                .whereType<Exercise>()
                                .map(
                                  (e) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.fitness_center,
                                      color: colors.primary,
                                    ),
                                    title: Text(e.name),
                                    subtitle: Text(
                                      '${e.muscle} · ${e.equipment}',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => context.push('/library'),
                                  ),
                                ),
                          ],
                          if (c.error != null) ErrorState(message: c.error!),
                          SizedBox(
                            height: MediaQuery.paddingOf(context).bottom + 30,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.at});
  final DateTime at;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: (width * .9).clamp(280, 500),
              child: ExcludeSemantics(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/home-hero-jade.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                    ColoredBox(
                      color: theme.extension<GlassPalette>()!.heroShade,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [.55, 1],
                          colors: [
                            colors.surface.withValues(alpha: 0),
                            colors.surface,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, "练迹"),
                    style: TextStyle(
                      fontSize: 23,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    tr(context, "{0}月{1}日 {2}", [
                      at.month,
                      at.day,
                      AppStrings.of(context).weekday(at.weekday, short: true),
                    ]),
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: (width * .29).clamp(72, 155)),
                  Text(
                    tr(context, "今天，也为自己\n留一点时间"),
                    style: TextStyle(
                      fontSize: width < 370 ? 30 : 32,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(context, "按自己的节奏开始。"),
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class EditorialSectionTitle extends StatelessWidget {
  const EditorialSectionTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 4,
        height: 15,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}

class _WorkoutIcon extends StatelessWidget {
  const _WorkoutIcon({required this.icon});
  final IconData? icon;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 25,
    backgroundColor: Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: .08),
    child: icon == null
        ? Image.asset(
            'assets/icons/arm-flex.png',
            key: const ValueKey('home-training-muscle'),
            width: 32,
            height: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            excludeFromSemantics: true,
          )
        : Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 25,
          ),
  );
}

class _RecentTrainingRow extends StatelessWidget {
  const _RecentTrainingRow({
    required this.title,
    this.subtitle,
    required this.onTap,
  });
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: .08),
      child: Image.asset(
        'assets/icons/recent-dumbbell.png',
        key: const ValueKey('home-recent-dumbbell'),
        width: 25,
        height: 25,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        excludeFromSemantics: true,
      ),
    ),
    title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
    subtitle: subtitle == null
        ? null
        : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _QuietMetric extends StatelessWidget {
  const _QuietMetric({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
