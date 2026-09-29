import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/native_system_calls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/system-calls');
  const id = 'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA';
  const callId = 'BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB';
  final event = <String, Object>{
    'eventId': id,
    'callId': callId,
    'account': 'member-test',
    'scope': 'direct',
    'kind': 'answer',
    'actionId': id,
  };

  test('normalizes call identity but preserves native action identity', () {
    final parsed = SystemCallEvent.parse(event);
    expect(parsed.callId, callId.toLowerCase());
    expect(parsed.actionId, id);
    expect(parsed.account, 'member-test');
    expect(parsed.kind, SystemCallEventKind.answer);
  });

  test(
    'rejects malformed and non-actionable payloads before calling native',
    () {
      for (final change in <Map<String, Object?>>[
        {'account': ''},
        {'account': '../account'},
        {'callId': 'not-a-call'},
        {'eventId': 'invalid'},
        {'scope': 'other'},
        {'kind': 'mute'},
        {'actionId': null},
        {'actionId': 'invalid'},
        {'kind': 'incoming'},
        {'kind': 'ended'},
      ]) {
        expect(
          () => SystemCallEvent.parse({...event, ...change}),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'notification acknowledgement cannot masquerade as successful answering',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final bridge = NativeSystemCalls(channel: channel);
      final parsed = SystemCallEvent.parse(event);
      await bridge.acknowledge(parsed);
      expect(calls.map((c) => c.method), ['ack']);
      await bridge.completeAction(parsed, success: false);
      expect(calls.last.method, 'completeAction');
      expect(calls.last.arguments, {'actionId': id, 'success': false});
      final ended = SystemCallEvent.parse(
        {...event, 'kind': 'ended'}..remove('actionId'),
      );
      await expectLater(
        bridge.completeAction(ended, success: true),
        throwsStateError,
      );
      expect(calls.length, 2);
    },
  );
}
