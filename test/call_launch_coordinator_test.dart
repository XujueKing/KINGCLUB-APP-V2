import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/call_launch_coordinator.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

const id = '00000000-0000-4000-8000-000000000001';
Map<String, dynamic> call(String phase) => {
  'callId': id,
  'caller': 'a',
  'callee': 'b',
  'mediaKind': 'audio',
  'phase': phase,
  'version': phase == 'ringing' ? 0 : 1,
  'deadlineMs': 9999999999999,
  if (phase == 'ended') ...{'endedAtMs': 9999999999998, 'endReason': 'hangup'},
};
Map<String, dynamic> relay() {
  final expiry = (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600) * 1000;
  return {
    'expiresAtMs': expiry,
    'iceServers': [
      {
        'urls': ['turn:relay.example'],
        'username': '${expiry ~/ 1000}:0123456789abcdef0123456789abcdef',
        'credential': 'AAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      },
    ],
  };
}

void main() {
  test('double dial coalesces, lost relay response retries same request and accepts early answer', () async {
    var failed = true;
    final ids = <String>[];
    final repository = CallRepository(
      MessagingRepository(
        account: 'a',
        call: (method, params) async {
          if (method == 'K260913000643') {
            ids.add(params['requestId'] as String);
            return call('ringing');
          }
          if (method == 'K260914000648') {
            if (failed) {
              failed = false;
              throw Exception('lost');
            }
            return relay();
          }
          return {'call': call('connecting')};
        },
      ),
    );
    final launch = CallLaunchCoordinator(repository);
    final first = launch.outgoing(peer: 'b', media: CallMedia.audio);
    expect(
      identical(first, launch.outgoing(peer: 'b', media: CallMedia.audio)),
      true,
    );
    await expectLater(first, throwsException);
    expect(
      () => launch.outgoing(peer: 'other', media: CallMedia.audio),
      throwsStateError,
    );
    final ready = await launch.outgoing(peer: 'b', media: CallMedia.audio);
    expect(ready.call.phase, CallPhase.connecting);
    expect(ready.outgoingAttempt, true);
    expect(ids.length, 2);
    expect(ids.first, ids.last);
    await expectLater(
      launch.finishOutgoing('00000000-0000-4000-8000-000000000002'),
      throwsStateError,
    );
    launch.close();
  });
  test('incoming cancelled during relay lookup never becomes a stale incoming page', () async {
    var reads = 0;
    final launch = CallLaunchCoordinator(
      CallRepository(
        MessagingRepository(
          account: 'b',
          call: (method, _) async {
            if (method == 'K260914000648') return relay();
            reads++;
            return {'call': call(reads == 1 ? 'ringing' : 'ended')};
          },
        ),
      ),
    );
    expect(await launch.incoming(), null);
    launch.close();
  });
  test('logout discards an in-flight setup without creating media or issuing more requests', () async {
    final response = Completer<Map<String, dynamic>>();
    var requests = 0;
    final launch = CallLaunchCoordinator(
      CallRepository(
        MessagingRepository(
          account: 'b',
          call: (_, _) {
            requests++;
            return response.future;
          },
        ),
      ),
    );
    final incoming = launch.incoming();
    launch.close();
    response.complete({'call': call('ringing')});
    await expectLater(incoming, throwsStateError);
    expect(requests, 1);
  });
}
