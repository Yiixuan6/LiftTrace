import '../l10n/app_strings.dart';
import 'dart:math' show pi, max;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../domain/models.dart';
import 'theme.dart';
import 'liquid_glass.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    required this.location,
    this.navigationShell,
  });
  final Widget child;
  final String location;
  final StatefulNavigationShell? navigationShell;
  @override
  Widget build(BuildContext context) {
    final index =
        navigationShell?.currentIndex ??
        (location.startsWith('/train') ||
                location.startsWith('/library') ||
                location.startsWith('/templates') ||
                location.startsWith('/schedule')
            ? 1
            : location.startsWith('/stats')
            ? 2
            : location.startsWith('/profile') ||
                  location.startsWith('/appearance') ||
                  location.startsWith('/body') ||
                  location.startsWith('/backup')
            ? 3
            : 0);
    const labels = ['首页', '训练', '统计', '我的'];
    const icons = [
      Icons.home_outlined,
      Icons.fitness_center,
      Icons.bar_chart,
      Icons.person_outline,
    ];
    void select(int i) {
      const paths = ['/', '/train', '/stats', '/profile'];
      if (index == i && location == paths[i]) return;
      FocusManager.instance.primaryFocus?.unfocus();
      if (navigationShell != null) {
        navigationShell!.goBranch(i, initialLocation: i == index);
      } else {
        context.go(paths[i]);
      }
    }

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 600;
        return Scaffold(
          // Clear liquid does not hide underlying text like frosted blur did.
          // Keep page foregrounds above the floating controls for legibility.
          extendBody: false,
          body: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (wide)
                  NavigationRail(
                    selectedIndex: index,
                    onDestinationSelected: select,
                    labelType: NavigationRailLabelType.all,
                    destinations: List.generate(
                      4,
                      (i) => NavigationRailDestination(
                        icon: i == 1
                            ? const TrainingNavigationIcon()
                            : Icon(icons[i]),
                        label: Text(tr(context, labels[i])),
                      ),
                    ),
                  ),
                Expanded(
                  child: Material(
                    type: MaterialType.transparency,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : SafeArea(
                  top: false,
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: GlassNavigationBar(
                          selectedIndex: index,
                          onDestinationSelected: select,
                        ),
                      ),
                      ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                        child: SizedBox(
                          height: max(
                            10,
                            MediaQuery.viewPaddingOf(context).bottom,
                          ),
                          width: double.infinity,
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// A clear refractive surface, with foreground controls on a stable tab shell.
class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  @override
  Widget build(BuildContext context) {
    const labels = ['首页', '训练', '统计', '我的'];
    const icons = [
      Icons.home_outlined,
      Icons.fitness_center,
      Icons.bar_chart,
      Icons.person_outline,
    ];
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    return LayoutBuilder(
      builder: (context, box) {
        final width = ((box.maxWidth - 14) / 4).clamp(1.0, double.infinity);
        var labelHeight = 0.0;
        for (final label in labels) {
          final painter = TextPainter(
            text: TextSpan(
              text: tr(context, label),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: width);
          labelHeight = max(labelHeight, painter.height);
          painter.dispose();
        }
        final height = max(
          56.0 + 18 * (scale - 1).clamp(0, 1),
          labelHeight + 34,
        );
        return LiquidGlassSurface(
          key: const ValueKey('glass-navigation'),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(48),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(
                    alpha: theme.brightness == Brightness.light ? .09 : .025,
                  ),
                  Colors.white.withValues(alpha: .005),
                  theme.colorScheme.primary.withValues(alpha: .012),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedAlign(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : ThemeTokens.quick,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment(-1 + selectedIndex * 2 / 3, 0),
                      child: FractionallySizedBox(
                        widthFactor: .25,
                        child: LiquidSelectionLens(
                          child: SizedBox(height: height),
                        ),
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: Row(
                      children: List.generate(4, (i) {
                        final selected = i == selectedIndex;
                        final color = selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface;
                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: selected,
                            label: tr(context, labels[i]),
                            child: Tooltip(
                              message: tr(context, labels[i]),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  key: ValueKey('main-nav-$i'),
                                  borderRadius: BorderRadius.circular(36),
                                  onTap: () => onDestinationSelected(i),
                                  child: SizedBox(
                                    height: height,
                                    child: ExcludeSemantics(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          i == 1
                                              ? TrainingNavigationIcon(
                                                  color: color,
                                                )
                                              : Icon(
                                                  selected && i == 0
                                                      ? Icons.home_rounded
                                                      : icons[i],
                                                  size: 27,
                                                  color: color,
                                                ),
                                          const SizedBox(height: 3),
                                          Text(
                                            tr(context, labels[i]),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 13,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class TrainingNavigationIcon extends StatelessWidget {
  const TrainingNavigationIcon({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: pi / 5,
    child: Image.asset(
      'assets/icons/recent-dumbbell.png',
      width: 27,
      height: 27,
      color: color ?? IconTheme.of(context).color,
      excludeFromSemantics: true,
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.actions = const [],
    this.root = false,
    this.preserveLayout = false,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children, actions;
  final bool root, preserveLayout;
  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.editorial(Theme.of(context)),
    child: Builder(
      builder: (context) => CustomScrollView(
        slivers: [
          if (!root)
            SliverAppBar(title: Text(title), floating: true, actions: actions),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ThemeTokens.maxWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    preserveLayout
                        ? ThemeTokens.gap
                        : MediaQuery.sizeOf(context).width < 360
                        ? 16
                        : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (root) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                    ),
                              ),
                            ),
                            ...actions,
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                          ),
                        ),
                      ...children.expand(
                        (w) => [w, const SizedBox(height: ThemeTokens.gap)],
                      ),
                      SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 19,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    ],
  );
}

class ContentPanel extends StatelessWidget {
  const ContentPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}

class MenuGroup extends StatelessWidget {
  const MenuGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Divider(),
            ),
          children[i],
        ],
      ],
    ),
  );
}

/// The caption is a separate layout box: it never floats across an input edge.
class FieldCaption extends StatelessWidget {
  const FieldCaption({super.key, required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ExcludeSemantics(
        child: Text(
          tr(context, label),
          key: ValueKey('caption-$label'),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Semantics(label: tr(context, label), child: child),
    ],
  );
}

class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.formField = false,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.enabled = true,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
  });
  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final bool formField, enabled, obscureText, autocorrect, enableSuggestions;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  @override
  Widget build(BuildContext context) => FieldCaption(
    label: label,
    child: formField
        ? TextFormField(
            key: ValueKey('input-$label'),
            controller: controller,
            initialValue: initialValue,
            enabled: enabled,
            keyboardType: keyboardType,
            textAlign: textAlign,
            maxLines: maxLines,
            obscureText: obscureText,
            autocorrect: autocorrect,
            enableSuggestions: enableSuggestions,
            decoration: const InputDecoration(),
            onChanged: onChanged,
            validator: validator == null
                ? null
                : (value) {
                    final error = validator!(value);
                    return error == null ? null : tr(context, error);
                  },
          )
        : TextField(
            key: ValueKey('input-$label'),
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            textAlign: textAlign,
            maxLines: maxLines,
            obscureText: obscureText,
            autocorrect: autocorrect,
            enableSuggestions: enableSuggestions,
            decoration: const InputDecoration(),
            onChanged: onChanged,
          ),
  );
}

/// All actions in a group have the same measured width and height, including
/// disabled controls and labels that wrap at large accessibility text sizes.
class EqualActionGroup extends StatelessWidget {
  const EqualActionGroup({
    super.key,
    required this.labels,
    required this.children,
  }) : assert(labels.length == children.length);
  final List<String> labels;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaler = MediaQuery.textScalerOf(context);
      final columns = box.maxWidth >= 300 && scaler.scale(17) <= 24 ? 2 : 1;
      final width = (box.maxWidth - (columns - 1) * 12) / columns;
      final style = Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );
      var height = 56.0;
      for (final label in labels) {
        final painter = TextPainter(
          text: TextSpan(text: tr(context, label), style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout(maxWidth: max(1, width - 40));
        height = max(height, painter.height + 28);
        painter.dispose();
      }
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children)
            SizedBox(width: width, height: height, child: child),
        ],
      );
    },
  );
}

class FieldGrid extends StatelessWidget {
  const FieldGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns =
          MediaQuery.textScalerOf(context).scale(14) > 21 || box.maxWidth < 270
          ? 1
          : box.maxWidth >= 650
          ? 3
          : 2;
      final width = (box.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class WorkoutCard extends StatelessWidget {
  const WorkoutCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.emphasis = false,
  });
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool emphasis;
  @override
  Widget build(BuildContext context) => Card(
    color: emphasis ? Theme.of(context).colorScheme.primaryContainer : null,
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(subtitle),
      ),
      trailing: trailing,
      onTap: onTap,
    ),
  );
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.trailing,
  });
  final Exercise exercise;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.fitness_center),
      title: Text(exercise.name),
      subtitle: Text(
        '${tr(context, exercise.muscle)} · ${tr(context, exercise.equipment)}',
      ),
      onTap: onTap,
      trailing: trailing,
    ),
  );
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.fluid = false,
  });
  final String label, value, unit;
  final bool fluid;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: fluid
        ? null
        : MediaQuery.textScalerOf(context).scale(172).clamp(172, 320),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                if (unit.isNotEmpty)
                  Text(unit, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.done, required this.goal});
  final int done, goal;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, "本周目标"),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(tr(context, "已完成 {0} 次 / 目标 {1} 次", [done, goal])),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: goal > 0 ? (done / goal).clamp(0, 1) : 0,
            semanticsLabel: tr(context, "本周训练进度"),
          ),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.action});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      children: [
        Icon(
          Icons.spa_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 16), child: action),
      ],
    ),
  );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: CircularProgressIndicator(semanticsLabel: tr(context, "正在加载")),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            trError(context, message),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(tr(context, "重试"))),
        ],
      ),
    ),
  );
}

Future<T?> showEditorialDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showDialog<T>(
  context: context,
  builder: (dialogContext) => Theme(
    data: AppTheme.editorial(Theme.of(dialogContext)),
    child: Builder(builder: builder),
  ),
);

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showEditorialDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, "取消")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, "确认")),
          ),
        ],
      ),
    ) ??
    false;

Future<String?> askText(
  BuildContext context,
  String title, {
  String initial = '',
}) async {
  final c = TextEditingController(text: initial);
  final result = await showEditorialDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, maxLength: 80),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, "取消")),
        ),
        FilledButton(
          onPressed: () {
            if (c.text.trim().isNotEmpty) Navigator.pop(context, c.text.trim());
          },
          child: Text(tr(context, "保存")),
        ),
      ],
    ),
  );
  // Dialog animations may still use the controller during removal.
  Future.delayed(const Duration(seconds: 1), c.dispose);
  return result;
}

Future<void> runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is FormatException ? e.message : tr(context, "操作失败，原数据保留，请重试。"),
          ),
        ),
      );
    }
  }
}
