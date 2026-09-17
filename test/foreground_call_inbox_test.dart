import 'dart:async';

import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/foreground_call_inbox.dart';
import 'package:kingclub/src/features/messaging/data/call_launch_coordinator.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/data/call_relay_configuration.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

const id = '00000000-0000-4000-8000-000000000001';
PreparedCall ready() {
  final expires = (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600) * 1000;
  return PreparedCall(
    CallSnapshot.parse({
      'callId': id,
      'caller': 'a',
      'callee': 'b',
      'mediaKind': 'audio',
      'phase': 'ringing',
      'version': 0,
      'deadlineMs': expires,
    }, 'b'),
    CallRelayConfiguration.parse(id, {
      'expiresAtMs': expires,
      'iceServers': [
        {
          'urls': ['turn:relay.example'],
          'username': '${expires ~/ 1000}:0123456789abcdef0123456789abcdef',
          'credential': 'AAAAAAAAAAAAAAAAAAAAAAAAAAA=',
        },
      ],
    }),
  );
}

class Launcher extends CallLaunchCoordinator {
  Launcher(this.read)
    : super(
        CallRepository(
          MessagingRepository(account: 'b', call: (_, _) async => {}),
        ),
      );
  final Future<PreparedCall?> Function() read;
  int reads = 0;
  @override
  Future<PreparedCall?> incoming() {
    reads++;
    return read();
  }
}

void main() {
  for (final resumed in [false, true]) {
    for (final code in ['INTERFACE_DISABLED', 'INTERFACE_NOT_FOUND']) {
      testWidgets(
        'interface error only stops its own foreground generation resumed=$resumed code=$code',
        (tester) async {
          final first = Completer<PreparedCall?>();
          var reads = 0, shown = 0;
          Future<PreparedCall?> read() async =>
              ++reads == 1 ? first.future : ready();
          final inbox = ForegroundCallInbox(
            launcher: Launcher(read),
            present: (_) async {
              shown++;
              return true;
            },
          );
          inbox.foreground(true);
          if (resumed) {
            inbox.foreground(false);
            inbox.foreground(true);
          }
          first.completeError(AuthFailure(code, 'fixture'));
          await tester.pump();
          expect(reads, resumed ? 2 : 1);
          expect(shown, resumed ? 1 : 0);
          if (!resumed) {
            await tester.pump(const Duration(seconds: 10));
            expect(reads, 1);
          }
          inbox.close();
        },
      );
    }
  }
  for (final resumed in [false, true]) {
    testWidgets(
      'notification during lookup is replayed without waiting for timer resumed=$resumed',
      (tester) async {
        final first = Completer<PreparedCall?>();
        var reads = 0, shown = 0;
        Future<PreparedCall?> read() async =>
            ++reads == 1 ? first.future : ready();
        final inbox = ForegroundCallInbox(
          launcher: Launcher(read),
          present: (_) async {
            shown++;
            return true;
          },
        );
        addTearDown(inbox.close);
        inbox.foreground(true);
        if (resumed) {
          inbox.foreground(false);
          inbox.foreground(true);
        } else {
          for (var n = 0; n < 10; n++) {
            inbox.notify();
          }
        }
        first.complete(null);
        await tester.pump();
        expect(reads, 2);
        expect(shown, 1);
        inbox.close();
      },
    );
  }
  testWidgets(
    'server without call interface stops polling until explicitly reactivated',
    (tester) async {
      final launcher = Launcher(
        () async =>
            throw const AuthFailure('INTERFACE_NOT_FOUND', 'unavailable'),
      );
      final inbox = ForegroundCallInbox(
        launcher: launcher,
        present: (_) async => true,
      );
      inbox.foreground(true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));
      expect(launcher.reads, 1);
      inbox.close();
    },
  );

  testWidgets(
    'duplicate notifications and timer ticks cannot stack incoming routes',
    (tester) async {
      final page = Completer<bool>();
      final launcher = Launcher(() async => ready());
      var presented = 0;
      final inbox = ForegroundCallInbox(
        launcher: launcher,
        present: (_) {
          presented++;
          return page.future;
        },
      );
      inbox.foreground(true);
      await tester.pump();
      final refresh = inbox.refresh();
      await tester.pump(const Duration(seconds: 15));
      expect(presented, 1);
      expect(launcher.reads, 1);
      page.complete(true);
      await tester.pump();
      await refresh;
      await inbox.refresh();
      expect(presented, 1);
      inbox.close();
    },
  );
  testWidgets('background and logout discard a late incoming result', (
    tester,
  ) async {
    final response = Completer<PreparedCall?>();
    final launcher = Launcher(() => response.future);
    var presented = 0;
    final inbox = ForegroundCallInbox(
      launcher: launcher,
      present: (_) async {
        presented++;
        return true;
      },
    );
    inbox.foreground(true);
    inbox.foreground(false);
    response.complete(ready());
    await tester.pump();
    expect(presented, 0);
    await tester.pump(const Duration(seconds: 10));
    expect(launcher.reads, 1);
    inbox.close();
    await inbox.refresh();
    expect(presented, 0);
  });
  testWidgets(
    'presentation unavailable can retry while a displayed call stays deduplicated',
    (tester) async {
      final launcher = Launcher(() async => ready());
      var presented = 0;
      final inbox = ForegroundCallInbox(
        launcher: launcher,
        present: (_) async => ++presented > 1,
      );
      inbox.foreground(true);
      await tester.pump();
      await inbox.refresh();
      expect(presented, 2);
      await inbox.refresh();
      expect(presented, 2);
      inbox.close();
    },
  );
}
