import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_flutter/gromore_flutter.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native logging channel accepts configuration', (tester) async {
    final plugin = GromoreFlutter.instance;
    final originalEnabled = GromoreLogger.enabled;
    final originalLevel = GromoreLogger.level;

    addTearDown(() async {
      await plugin.setLogLevel(originalLevel);
      await plugin.setLogEnabled(originalEnabled);
    });

    await expectLater(plugin.setLogEnabled(false), completes);
    expect(GromoreLogger.enabled, isFalse);

    await expectLater(plugin.setLogLevel(LogLevel.warn), completes);
    expect(GromoreLogger.level, LogLevel.warn);

    await expectLater(plugin.setLogEnabled(true), completes);
    expect(GromoreLogger.enabled, isTrue);
  });
}
