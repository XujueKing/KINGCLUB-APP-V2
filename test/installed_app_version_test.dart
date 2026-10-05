import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/app_version.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kingclub/app-version');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  testWidgets(
    'displays installed version and build instead of a source constant',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'read');
            return {'version': '2.3.4', 'build': '987'};
          });
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: InstalledAppVersion())),
      );
      await tester.pumpAndSettle();
      expect(find.text('2.3.4 (987)'), findsOneWidget);
      expect(find.textContaining('1.0.0'), findsNothing);
    },
  );
  testWidgets('missing native metadata does not invent a build', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InstalledAppVersion())),
    );
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
