import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/background_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackgroundNotifications.channel, (
          call,
        ) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackgroundNotifications.channel, null);
  });
  test('slow unread recovery never delays incoming calls', () async {
    final blocked = Completer<void>();
    final events = <String>[];
    final runtime = BackgroundNotifications.forTesting((event) async {
      final type = event['eventType'] as String;
      events.add(type);
      if (type == 'receiver.checkUnread') await blocked.future;
    });
    runtime.foreground(false);
    runtime.notify({'eventType': 'connection.ready'});
    await Future<void>.delayed(Duration.zero);
    runtime.notify({'eventType': 'chat.call.changed'});
    runtime.notify({'eventType': 'chat.group.call.changed'});
    await Future<void>.delayed(Duration.zero);
    expect(
      events,
      containsAll([
        'receiver.checkCalls',
        'receiver.checkUnread',
        'chat.call.changed',
        'chat.group.call.changed',
      ]),
    );
    expect(blocked.isCompleted, false);
    expect(
      events.indexOf('chat.call.changed'),
      lessThan(events.indexOf('chat.group.call.changed')),
    );
    blocked.complete();
  });
  test(
    'queued call after resume is discarded even behind a failed request',
    () async {
      final blocked = Completer<void>();
      var handled = 0;
      final runtime = BackgroundNotifications.forTesting((_) async {
        handled++;
        await blocked.future;
      });
      runtime.foreground(false);
      runtime.notify({'eventType': 'chat.call.changed'});
      await Future<void>.delayed(Duration.zero);
      runtime.notify({'eventType': 'chat.group.call.changed'});
      runtime.foreground(true);
      blocked.completeError(StateError('network failed'));
      await Future<void>.delayed(Duration.zero);
      expect(handled, 1);
    },
  );
  test(
    'resume withdraws call notices; reset unbinds the previous account',
    () async {
      final runtime = BackgroundNotifications();
      runtime.foreground(false);
      runtime.foreground(true);
      runtime.reset();
      await Future<void>.delayed(Duration.zero);
      expect(calls.map((call) => call.method), ['clearCalls', 'bind']);
      expect(calls.last.arguments, {'session': null});
    },
  );
  test(
    'resuming before queued event runs prevents background lookup',
    () async {
      final runtime = BackgroundNotifications();
      runtime.foreground(false);
      runtime.notify({'eventType': 'connection.ready'});
      runtime.foreground(true);
      await Future<void>.delayed(Duration.zero);
      expect(calls.map((call) => call.method), ['clearCalls']);
    },
  );
}
