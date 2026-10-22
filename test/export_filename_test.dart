import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lianji/platform/export_filename.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.lianji.training/app-info');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'all export types use the installed label and local calendar date',
    () async {
      for (final label in ['练迹', '练迹验证', '练迹设计验收']) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getApplicationName');
          return label;
        });
        for (final extension in ['json', 'csv']) {
          expect(
            await exportFilename(extension, now: DateTime(2026, 1, 2, 23, 59)),
            '$label-2026-01-02.$extension',
          );
          expect(
            await exportFilename(extension, now: DateTime(2026, 1, 3)),
            '$label-2026-01-03.$extension',
          );
        }
      }
    },
  );

  test(
    'missing native label fails explicitly instead of misnaming the backup',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => '');
      await expectLater(exportFilename('json'), throwsFormatException);
    },
  );
}
