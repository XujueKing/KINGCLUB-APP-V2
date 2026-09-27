import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/background_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackgroundNotifications.channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackgroundNotifications.channel, null);
  });
  test('resume withdraws call notices; reset unbinds the previous account', () async {
    final runtime = BackgroundNotifications();
    runtime.foreground(false);
    runtime.foreground(true);
    runtime.reset();
    await Future<void>.delayed(Duration.zero);
    expect(calls.map((call) => call.method), ['clearCalls', 'bind']);
    expect(calls.last.arguments, {'session': null});
  });
  test('resuming before queued event runs prevents background lookup', () async {
    final runtime = BackgroundNotifications();
    runtime.foreground(false);
    runtime.notify({'eventType': 'connection.ready'});
    runtime.foreground(true);
    await Future<void>.delayed(Duration.zero);
    expect(calls.map((call) => call.method), ['clearCalls']);
  });
}
