import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lianji/l10n/app_strings.dart';
import '../test/input_editing_test.dart' as editing;

// Functional native regression only. This debug runner is NOT a performance
// benchmark and does not establish physical keyboard or profile frame latency.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    expect(
      await const MethodChannel(
        'app.lianji.training/app-info',
      ).invokeMethod<String>('getApplicationName'),
      '练迹设计验收',
    );
    await AppStrings.prepare();
  });
  editing.main(native: true);
}
