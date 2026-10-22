import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lianji/platform/reminders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  var allowed = true, exact = true, vibration = true, importance = 4;
  var launched = false;
  var initializeFails = false;
  late RestReminders reminders;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    allowed = exact = vibration = true;
    importance = 4;
    launched = false;
    initializeFails = false;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize' && initializeFails) {
            throw PlatformException(code: 'invalid_icon');
          }
          return switch (call.method) {
            'initialize' => true,
            'areNotificationsEnabled' ||
            'requestNotificationsPermission' => allowed,
            'canScheduleExactNotifications' ||
            'requestExactAlarmsPermission' => exact,
            'getNotificationChannels' => [
              {
                'id': RestReminders.channelId,
                'name': 'rest',
                'importance': importance,
                'showBadge': false,
                'bypassDnd': false,
                'playSound': true,
                'enableLights': false,
                'enableVibration': vibration,
                'vibrationPattern': null,
                'ledColor': 0,
                'audioAttributesUsage': 5,
              },
            ],
            'getNotificationAppLaunchDetails' => {
              'notificationLaunchedApp': launched,
              'notificationResponse': {
                'notificationResponseType': 0,
                'payload': 'rest',
              },
            },
            _ => null,
          };
        });
    reminders = RestReminders(isAndroid: true);
  });
  tearDown(() {
    reminders.dispose();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('启动仅创建高重要性震动通道，不自动请求权限或全屏', () async {
    await reminders.initialize();
    final create =
        calls
                .singleWhere((c) => c.method == 'createNotificationChannel')
                .arguments
            as Map;
    final config = create;
    expect(config['id'], 'rest_alerts_v2');
    expect(config['importance'], 4);
    expect(config['enableVibration'], true);
    expect(config['vibrationPattern'], [0, 350, 150, 350, 150, 500]);
    expect(config['bypassDnd'], false);
    expect(calls.where((c) => c.method.startsWith('request')), isEmpty);
    expect(
      (calls.firstWhere((c) => c.method == 'initialize').arguments
          as Map)['defaultIcon'],
      'ic_notification',
    );
  });
  test('发布初始化失败不冒充无权限，恢复资源后能重试成功', () async {
    initializeFails = true;
    await expectLater(
      reminders.initialize(),
      throwsA(isA<PlatformException>()),
    );
    final failed = await reminders.status();
    expect(failed.initializationFailed, true);
    expect(failed.message, contains('初始化失败'));
    expect(failed.message, isNot(contains('请允许通知')));
    expect(calls.where((c) => c.method.startsWith('request')), isEmpty);
    initializeFails = false;
    final recovered = await reminders.status();
    expect(recovered.ready, true);
    expect(recovered.initializationFailed, false);
  });
  test('精确后台闹钟、通道震动和返回训练payload正确，重设先撤旧提醒', () async {
    await reminders.initialize();
    calls.clear();
    final result = await reminders.schedule(
      DateTime.now().add(const Duration(seconds: 90)),
    );
    expect(result.ready, true);
    final methods = calls.map((c) => c.method).toList();
    expect(
      methods.indexOf('cancel'),
      lessThan(methods.indexOf('zonedSchedule')),
    );
    final args =
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments as Map;
    expect(args['id'], 71);
    expect(args['payload'], 'rest');
    final details = args['platformSpecifics'] as Map;
    expect(details['channelId'], 'rest_alerts_v2');
    expect(details['enableVibration'], true);
    expect(details['vibrationPattern'], [0, 350, 150, 350, 150, 500]);
    expect(details['fullScreenIntent'], false);
    expect(details['category'], 'alarm');
    expect(details['scheduleMode'], 'alarmClock');
    await reminders.cancel();
    expect(calls.last.method, 'cancel');
  });
  test('拒绝通知、低重要性与禁震分别报告；缺精确权限明确延迟', () async {
    await reminders.initialize();
    allowed = false;
    expect((await reminders.status()).message, contains('允许通知'));
    allowed = true;
    vibration = false;
    expect((await reminders.status()).ready, false);
    expect((await reminders.status()).message, contains('振动'));
    vibration = true;
    importance = 2;
    expect((await reminders.status()).popupAllowed, false);
    importance = 4;
    exact = false;
    final status = await reminders.schedule(
      DateTime.now().add(const Duration(seconds: 90)),
    );
    expect(status.ready, false);
    expect(status.message, contains('延迟'));
    final args =
        calls.lastWhere((c) => c.method == 'zonedSchedule').arguments as Map;
    expect(
      (args['platformSpecifics'] as Map)['scheduleMode'],
      'inexactAllowWhileIdle',
    );
  });
  test('过期截止时间取消旧闹钟而不重新安排', () async {
    await reminders.initialize();
    calls.clear();
    await reminders.schedule(
      DateTime.now().subtract(const Duration(seconds: 1)),
    );
    expect(calls.any((c) => c.method == 'cancel'), true);
    expect(calls.any((c) => c.method == 'zonedSchedule'), false);
  });
  test('冷启动只有实际来自休息通知才回跳；振动总开关入口使用应用设置', () async {
    await reminders.initialize();
    expect(await reminders.launchedFromRest(), false);
    launched = true;
    expect(await reminders.launchedFromRest(), true);
    const settings = MethodChannel('app.lianji.training/reminders');
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(settings, (call) async {
          received = call;
          return null;
        });
    try {
      await reminders.openSettings(applicationLevel: true);
      expect(received!.method, 'openNotificationSettings');
      expect(received!.arguments, true);
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(settings, null);
    }
  });
  test(
    'reminders change language without changing the pending deadline or notification identity',
    () async {
      var language = 'en';
      reminders.dispose();
      reminders = RestReminders(
        isAndroid: true,
        languagePreference: () => language,
      );
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      await reminders.schedule(deadline);
      final english =
          calls.lastWhere((c) => c.method == 'zonedSchedule').arguments as Map;
      expect(english['title'], 'Rest complete');
      language = 'zh_Hant';
      await reminders.refreshLanguage();
      final traditional =
          calls.lastWhere((c) => c.method == 'zonedSchedule').arguments as Map;
      expect(traditional['title'], '休息結束');
      expect(traditional['id'], english['id']);
      expect(traditional['scheduledDateTime'], english['scheduledDateTime']);
      await reminders.cancel();
      final count = calls.where((c) => c.method == 'zonedSchedule').length;
      language = 'en';
      await reminders.refreshLanguage();
      expect(calls.where((c) => c.method == 'zonedSchedule').length, count);
    },
  );
}
