import 'dart:async';
import 'package:flutter/widgets.dart';
import '../l10n/app_strings.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class RestReminderStatus {
  const RestReminderStatus({
    this.supported = false,
    this.notificationsAllowed = false,
    this.exactAllowed = false,
    this.popupAllowed = false,
    this.vibrationAllowed = false,
    this.initializationFailed = false,
  });
  final bool supported, notificationsAllowed, exactAllowed;
  final bool popupAllowed, vibrationAllowed;
  final bool initializationFailed;
  bool get ready =>
      notificationsAllowed && exactAllowed && popupAllowed && vibrationAllowed;
  String get message {
    if (initializationFailed) return '提醒组件初始化失败，计时仍可使用；请点重试';
    if (!supported) return '系统提醒暂不可用，应用内计时仍可使用';
    if (!notificationsAllowed) return '请允许通知，才能在其他应用中收到休息提醒';
    if (!popupAllowed) return '请在通知设置中开启横幅弹出';
    if (!vibrationAllowed) return '请在系统的应用通知设置中开启振动';
    if (!exactAllowed) return '未允许精确提醒，后台通知可能延迟';
    return '切到其他应用后，到时通过系统通知弹出并震动';
  }
}

class RestReminders with WidgetsBindingObserver {
  RestReminders({bool? isAndroid, this.onOpenRest, this.languagePreference})
    : _isAndroid = isAndroid ?? Platform.isAndroid;
  final bool _isAndroid;
  final String? Function()? languagePreference;
  AppStrings _strings = AppStrings(AppStrings.simplified);
  DateTime? _scheduledDeadline;
  bool _observingLocale = false;

  Future<void> _loadLanguage() async {
    final preference = languagePreference?.call();
    final locale =
        AppStrings.preferred(preference) ??
        AppStrings.resolve(WidgetsBinding.instance.platformDispatcher.locale);
    _strings = await AppStrings.load(locale);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (languagePreference?.call() == 'system') {
      unawaited(refreshLanguage().catchError((Object _) {}));
    }
  }

  Future<void> refreshLanguage() async {
    if (!_isAndroid) return;
    await _loadLanguage();
    if (!initialized) return;
    await _createChannel();
    final deadline = _scheduledDeadline;
    if (deadline != null && deadline.isAfter(DateTime.now())) {
      await schedule(deadline);
    }
  }

  Future<void> _createChannel() async {
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        _strings.text('组间休息 · 弹出与震动'),
        description: _strings.text('完成一组后的休息到时提醒，可在其他应用中显示'),
        importance: Importance.high,
        enableVibration: true,
        vibrationPattern: vibrationPattern,
        playSound: true,
        showBadge: false,
      ),
    );
  }

  final void Function()? onOpenRest;
  static const notificationId = 71;
  // Channel behavior is immutable on Android. Keep the old channel untouched.
  static const channelId = 'rest_alerts_v2';
  static final vibrationPattern = Int64List.fromList([
    0,
    350,
    150,
    350,
    150,
    500,
  ]);
  static const _settings = MethodChannel('app.lianji.training/reminders');
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  bool initialized = false;
  bool initializationFailed = false;
  Future<void>? _initializing;
  Future<void> initialize() {
    if (!_isAndroid || initialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    try {
      await _initializePlugin();
      initializationFailed = false;
    } catch (_) {
      initializationFailed = true;
      rethrow;
    }
  }

  Future<void> _initializePlugin() async {
    await _loadLanguage();
    tzdata.initializeTimeZones();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'rest') onOpenRest?.call();
      },
    );
    await _createChannel();
    if (!_observingLocale) {
      WidgetsBinding.instance.addObserver(this);
      _observingLocale = true;
    }
    initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<RestReminderStatus> status() async {
    if (!_isAndroid) return const RestReminderStatus();
    if (!initialized) {
      try {
        await initialize();
      } catch (_) {
        return const RestReminderStatus(
          supported: true,
          initializationFailed: true,
        );
      }
    }
    final android = _android;
    final channels = await android?.getNotificationChannels() ?? [];
    final channel = channels.where((c) => c.id == channelId).firstOrNull;
    Map<dynamic, dynamic>? native;
    try {
      native = await _settings.invokeMapMethod<dynamic, dynamic>(
        'getChannelStatus',
      );
    } on MissingPluginException {
      // Host tests and plugin-only harnesses use the plugin channel metadata.
    }
    return RestReminderStatus(
      supported: true,
      notificationsAllowed: await android?.areNotificationsEnabled() ?? false,
      exactAllowed: await android?.canScheduleExactNotifications() ?? false,
      popupAllowed:
          (native?['importance'] as int? ?? channel?.importance.value ?? 0) >=
          Importance.high.value,
      vibrationAllowed:
          native?['vibration'] as bool? ?? channel?.enableVibration ?? false,
    );
  }

  Future<bool> launchedFromRest() async {
    if (!initialized) return false;
    final details = await plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true &&
        details?.notificationResponse?.payload == 'rest';
  }

  Future<void> openSettings({bool applicationLevel = false}) async {
    if (initialized) {
      await _settings.invokeMethod<void>(
        'openNotificationSettings',
        applicationLevel,
      );
    }
  }

  Future<void> openBackgroundSettings() async {
    if (initialized) {
      await _settings.invokeMethod<void>('openBackgroundSettings');
    }
  }

  Future<bool> requestPermissions({bool precise = false}) async {
    await initialize();
    if (!initialized) return false;
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission() ?? false;
    if (precise) await android?.requestExactAlarmsPermission();
    return granted;
  }

  Future<RestReminderStatus> schedule(DateTime deadline) async {
    await initialize();
    if (!initialized) return const RestReminderStatus();
    await _loadLanguage();
    await cancel();
    if (!deadline.isAfter(DateTime.now())) return status();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    await plugin.zonedSchedule(
      notificationId,
      _strings.text('休息结束'),
      _strings.text('按自己的节奏，继续下一组。'),
      tz.TZDateTime.from(deadline, tz.UTC),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _strings.text('组间休息 · 弹出与震动'),
          channelDescription: _strings.text('完成一组后的休息到时提醒，可在其他应用中显示'),
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: vibrationPattern,
          playSound: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          channelShowBadge: false,
        ),
      ),
      androidScheduleMode: exact
          // Explicit short workout timers must not share the idle-alarm quota
          // with repeated background jobs. This still posts a normal banner;
          // it does not launch a full-screen activity.
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'rest',
    );
    _scheduledDeadline = deadline;
    return status();
  }

  void dispose() {
    if (_observingLocale) WidgetsBinding.instance.removeObserver(this);
    _observingLocale = false;
  }

  Future<void> cancel() async {
    _scheduledDeadline = null;
    if (initialized) await plugin.cancel(notificationId);
  }
}
