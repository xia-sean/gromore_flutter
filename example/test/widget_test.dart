import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_flutter/gromore_flutter.dart';
import 'package:gromore_flutter_example/main.dart';

void main() {
  tearDown(() {
    GromoreLogger.setHandler(null);
  });

  testWidgets('example starts on the settings page', (tester) async {
    await tester.pumpWidget(const GromoreExampleApp());

    expect(find.text('GroMore Flutter Example'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(9));
    expect(find.byType(SettingsPage).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward video requires SDK initialization before showing',
      (tester) async {
    await tester.pumpWidget(const GromoreExampleApp());

    await tester.tap(find.text('激励'));
    await tester.pumpAndSettle();

    expect(find.text('激励视频').hitTestable(), findsOneWidget);
    await tester.tap(find.text('展示').hitTestable());
    await tester.pump();

    expect(find.text('请先初始化 SDK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
