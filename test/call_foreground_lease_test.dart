import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/call_foreground_lease.dart';

void main() {
  test(
    'background eligibility requires native acknowledgement and live owner',
    () async {
      final pending = Completer<void>();
      final lease = CallForegroundLease(
        supported: true,
        invoke: (method, _) async {
          if (method == 'start') await pending.future;
        },
      );
      final starting = lease.start(video: false);
      expect(lease.isActive, false);
      pending.complete();
      await starting;
      expect(lease.isActive, true);
      await lease.close();
      expect(lease.isActive, false);
      final unsupported = CallForegroundLease(supported: false);
      await unsupported.start(video: false);
      expect(unsupported.isActive, false);
      await unsupported.close();
    },
  );
  test('late start after close is stopped with the same lease', () async {
    final pending = Completer<void>();
    final calls = <(String, Map<String, dynamic>)>[];
    final lease = CallForegroundLease(
      supported: true,
      invoke: (method, args) async {
        calls.add((method, args));
        if (method == 'start') await pending.future;
      },
    );
    final started = lease.start(video: true);
    final failed = expectLater(started, throwsStateError);
    await lease.close();
    pending.complete();
    await failed;
    expect(lease.isActive, false);
    expect(calls.map((c) => c.$1), ['start', 'stop', 'stop']);
    expect(calls.map((c) => c.$2['id']).toSet().length, 1);
    expect(calls.first.$2['video'], true);
  });
  test('failed native start cleans up and does not retry capture', () async {
    final calls = <String>[];
    final lease = CallForegroundLease(
      supported: true,
      invoke: (method, _) async {
        calls.add(method);
        if (method == 'start') throw StateError('permission denied');
      },
    );
    await expectLater(lease.start(video: false), throwsStateError);
    expect(lease.isActive, false);
    await expectLater(lease.start(video: false), throwsStateError);
    expect(calls, ['start', 'stop']);
    await lease.close();
  });
}
