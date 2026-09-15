import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/group_call_controller.dart';
import 'package:kingclub/src/features/messaging/data/group_call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

const id = '00000000-0000-4000-8000-000000000001';
const group = '00000000-0000-4000-8000-000000000002';
Map<String, dynamic> state(int version, [String self = 'invited']) => {
  'callId': id,
  'groupId': group,
  'mediaKind': 'audio',
  'version': version,
  'endedAtMs': null,
  'participants': [
    {'account': 'me', 'phase': self, 'deadlineMs': 9999999999999},
    {'account': 'friend', 'phase': 'joined', 'deadlineMs': 9999999999999},
  ],
};
Future<void> tick() => Future<void>.delayed(Duration.zero);
void main() {
  late StreamController<void> sessions, updates;
  late GroupCallController controller;
  GroupCallController create(ChatApiCall api) =>
      controller = GroupCallController(
        repository: GroupCallRepository(
          MessagingRepository(account: 'me', call: api),
        ),
        initial: GroupCallSnapshot.parse(state(0), 'me'),
        sessionChanges: sessions.stream,
        invalidations: updates.stream,
        pollInterval: const Duration(hours: 1),
      );
  setUp(() {
    sessions = StreamController<void>.broadcast(sync: true);
    updates = StreamController<void>.broadcast(sync: true);
  });
  tearDown(() async {
    controller.dispose();
    await sessions.close();
    await updates.close();
  });

  test(
    'notifications coalesce into reads without implicit accept or heartbeat',
    () async {
      final first = Completer<Map<String, dynamic>>();
      var reads = 0;
      create((api, params) async {
        expect(api, 'K260915000680');
        reads++;
        return reads == 1 ? first.future : state(1);
      }).watch();
      await tick();
      updates.add(null);
      updates.add(null);
      expect(reads, 1);
      first.complete(state(0));
      await tick();
      await tick();
      expect(reads, 2);
      expect(controller.call.version, 1);
    },
  );

  test('session change drops late reads and queued actions', () async {
    final response = Completer<Map<String, dynamic>>();
    var calls = 0;
    create((_, _) {
      calls++;
      return response.future;
    });
    final read = controller.refresh();
    await tick();
    final action = controller.act(GroupCallAction.join);
    sessions.add(null);
    response.complete(state(1, 'joined'));
    await read;
    await action;
    expect(controller.isClosed, true);
    expect(controller.call.version, 0);
    expect(calls, 1);
  });

  test('continuous invalidations cannot starve a queued user action', () async {
    final first = Completer<Map<String, dynamic>>();
    final second = Completer<Map<String, dynamic>>();
    final order = <String>[];
    create((api, params) async {
      if (api == 'K260915000680') {
        order.add('read');
        return order.length == 1 ? first.future : second.future;
      }
      order.add('action');
      expect(params['expectedVersion'], 2);
      return {...state(3, 'joined'), 'appliedVersion': 3, 'replay': false};
    }).watch();
    await tick();
    updates.add(null);
    final action = controller.act(GroupCallAction.join);
    first.complete(state(1));
    await tick();
    updates.add(null);
    second.complete(state(2));
    await action;
    expect(order, ['read', 'read', 'action']);
    expect(controller.call.version, 3);
  });

  test(
    'uncertain action retry retains ID and original version after refresh',
    () async {
      final attempts = <Map<String, dynamic>>[];
      create((api, params) async {
        if (api == 'K260915000680') {
          return state(1, 'joined');
        }
        attempts.add(params);
        if (attempts.length == 1) {
          throw const AuthFailure('NETWORK_ERROR', 'offline');
        }
        return {...state(1, 'joined'), 'appliedVersion': 1, 'replay': true};
      });
      await expectLater(
        controller.act(GroupCallAction.join),
        throwsA(isA<AuthFailure>()),
      );
      await controller.refresh();
      await controller.act(GroupCallAction.join);
      expect(attempts.first, attempts.last);
      expect(controller.error, null);
      expect(controller.call.version, 1);
    },
  );

  test(
    'definite version conflict syncs and next explicit attempt uses a new ID',
    () async {
      final attempts = <Map<String, dynamic>>[];
      create((api, params) async {
        if (api == 'K260915000680') {
          return state(1);
        }
        attempts.add(params);
        if (attempts.length == 1) {
          throw const AuthFailure(
            'CHAT_GROUP_CALL_VERSION_CONFLICT',
            'changed',
          );
        }
        return {...state(2, 'joined'), 'appliedVersion': 2, 'replay': false};
      });
      await expectLater(
        controller.act(GroupCallAction.join),
        throwsA(isA<AuthFailure>()),
      );
      expect(controller.call.version, 1);
      expect(attempts.length, 1);
      await controller.act(GroupCallAction.join);
      expect(attempts.last['expectedVersion'], 1);
      expect(attempts.first['requestId'], isNot(attempts.last['requestId']));
    },
  );

  test('revoked participant closes without further requests', () async {
    var calls = 0;
    create((_, _) async {
      calls++;
      return state(1, 'revoked');
    });
    await controller.refresh();
    expect(controller.isClosed, true);
    await controller.refresh();
    await controller.act(GroupCallAction.join);
    expect(calls, 1);
  });

  test(
    'event adapter forwards group call and reconnect invalidations only',
    () async {
      create((_, _) async => state(0));
      final source = StreamController<Map<String, dynamic>>();
      final received = groupCallInvalidations(source.stream).toList();
      source.add({'eventType': 'chat.call.changed'});
      source.add({'eventType': 'chat.group.message'});
      source.add({
        'eventType': 'chat.group.call.changed',
        'data': {'eventId': 'test'},
      });
      source.add({'eventType': 'connection.ready'});
      await source.close();
      expect((await received).length, 2);
    },
  );
}
