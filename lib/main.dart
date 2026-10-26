import 'l10n/app_strings.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'application/controller.dart';
import 'data/repository.dart';
import 'domain/models.dart';
import 'platform/background_backup.dart';
import 'platform/reminders.dart';
import 'ui/active_workout.dart';
import 'ui/backup_page.dart';
import 'ui/body.dart';
import 'ui/components.dart';
import 'ui/history.dart';
import 'ui/home.dart';
import 'ui/library.dart';
import 'ui/profile.dart';
import 'ui/statistics_page.dart';
import 'ui/templates.dart';
import 'ui/theme.dart';
import 'ui/liquid_glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStrings.prepare();
  await LiquidGlassSurface.prepare();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Pictogrammers Material Design Icons · arm-flex',
    ], await rootBundle.loadString('assets/licenses/mdi.txt'));
    yield LicenseEntryWithLineBreaks([
      'Font Awesome Free · dumbbell',
    ], await rootBundle.loadString('assets/licenses/fontawesome.txt'));
  });
  try {
    final repository = await SqliteTrainingRepository.open();
    final controller = AppController(repository, await repository.load());
    void openRest() => appRouter.go(
      controller.data.active == null ? '/train' : '/train/active',
    );
    final reminders = RestReminders(
      onOpenRest: openRest,
      languagePreference: () => controller.data.settings['language'] as String?,
    );
    var openedFromRest = false;
    try {
      await reminders.initialize();
      openedFromRest = await reminders.launchedFromRest();
    } catch (_) {
      /* Local training works without system services. */
    }
    try {
      await BackgroundBackup.initialize();
    } catch (_) {
      /* Local data remains available. */
    }
    final deadline = DateTime.tryParse(
      controller.data.settings['restDeadline'] as String? ?? '',
    );
    try {
      if (deadline != null && deadline.isAfter(DateTime.now())) {
        await reminders.schedule(deadline);
      } else {
        await reminders.cancel();
      }
    } catch (_) {
      /* Timer continues in-app. */
    }
    var reminderLanguage = controller.data.settings['language'];
    controller.onChanged = () async {
      final language = controller.data.settings['language'];
      if (reminderLanguage != language) {
        reminderLanguage = language;
        try {
          await reminders.refreshLanguage();
        } catch (_) {
          /* Timer remains available. */
        }
      }
      if (controller.data.settings['autoBackup'] == true) {
        await BackgroundBackup.schedule();
      }
    };
    if (Platform.isAndroid && controller.data.settings['autoBackup'] == true) {
      try {
        await BackgroundBackup.schedule();
      } catch (_) {
        /* Background restrictions must not block local training. */
      }
    }
    runApp(
      ProviderScope(
        overrides: [
          controllerProvider.overrideWith((ref) => controller),
          remindersProvider.overrideWithValue(reminders),
        ],
        child: const LianjiApp(),
      ),
    );
    if (openedFromRest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => openRest());
    }
  } catch (_) {
    runApp(
      MaterialApp(
        supportedLocales: AppStrings.supportedLocales,
        localeListResolutionCallback: (locales, _) =>
            AppStrings.resolve(locales?.firstOrNull),
        localizationsDelegates: const [
          AppStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: AppTheme.build(BrandTheme.orange, Brightness.light),
        home: const Scaffold(
          body: SafeArea(
            child: ErrorState(message: '本地数据暂时无法读取。为保护数据未重置数据库，请重新启动或联系维护者。'),
          ),
        ),
      ),
    );
  }
}

final appRouter = GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppScaffold(
        location: state.uri.path,
        navigationShell: shell,
        child: shell,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomePage()),
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      ActiveWorkoutPage(sessionId: state.pathParameters['id']),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/train',
              builder: (context, state) => const TrainPage(),
              routes: [
                GoRoute(
                  path: 'active',
                  builder: (context, state) => const ActiveWorkoutPage(),
                ),
              ],
            ),
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryPage(),
            ),
            GoRoute(
              path: '/templates',
              builder: (context, state) => const TemplatesPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      TemplateEditor(id: state.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: '/schedule',
              builder: (context, state) => const SchedulePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/stats',
              builder: (context, state) => const StatisticsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
            ),
            GoRoute(
              path: '/appearance',
              builder: (context, state) => const AppearancePage(),
            ),
            GoRoute(
              path: '/body',
              builder: (context, state) => const BodyPage(),
            ),
            GoRoute(
              path: '/backup',
              builder: (context, state) => const BackupPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class LianjiApp extends ConsumerWidget {
  const LianjiApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (brandName, appearanceName, language) = ref.watch(
      controllerProvider.select(
        (c) => (
          c.data.settings['brand'] as String,
          c.data.settings['appearance'] as String,
          c.data.settings['language'] as String?,
        ),
      ),
    );
    final brand = BrandTheme.values.byName(brandName);
    final mode = Appearance.values.byName(appearanceName);
    return MaterialApp.router(
      locale: AppStrings.preferred(language),
      supportedLocales: AppStrings.supportedLocales,
      localeListResolutionCallback: (locales, _) =>
          AppStrings.resolve(locales?.firstOrNull),
      localizationsDelegates: const [
        AppStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : ThemeTokens.quick,
      onGenerateTitle: (context) => tr(context, '练迹 · 训练日志'),
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.build(brand, Brightness.light),
      darkTheme: AppTheme.build(brand, Brightness.dark),
      themeMode: ThemeMode.values[mode.index],
      builder: (context, child) {
        final colors = Theme.of(context).colorScheme,
            dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: colors.surface,
            systemNavigationBarIconBrightness: dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: child!,
        );
      },
    );
  }
}
