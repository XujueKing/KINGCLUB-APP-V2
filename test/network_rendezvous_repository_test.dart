import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/network_rendezvous_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

const own = '11111111-1111-4111-8111-111111111111';
const peer = '22222222-2222-4222-8222-222222222222';
const exchange = '33333333-3333-4333-8333-333333333333';
Map<String, dynamic> state({bool incoming = false}) => {
  'exchangeId': exchange,
  'fromBindingId': incoming ? peer : own,
  'toBindingId': incoming ? own : peer,
  'offer': {
    'signed': {'data': 1},
  },
  'answer': null,
  'cancelled': false,
  'expiresAtMs': DateTime.now().millisecondsSinceEpoch + 45000,
};
NetworkRendezvousRepository repo(ChatApiCall call) =>
    NetworkRendezvousRepository(
      messaging: MessagingRepository(account: 'me', call: call),
      peer: 'friend',
      ownBindingId: own,
      peerBindingId: peer,
    );
void main() {
  test(
    'passive construction and caller-owned retry preserve request identity',
    () async {
      final requests = <Map<String, dynamic>>[];
      final response = state();
      final client = repo((api, params) async {
        expect(api, 'K260915000683');
        requests.add(params);
        if (requests.length == 1) throw StateError('network interrupted');
        return {'exchange': response};
      });
      expect(requests, isEmpty);
      final payload = {
        'signed': {'data': 1},
      };
      await expectLater(client.offer(exchange, payload), throwsStateError);
      expect((await client.offer(exchange, payload)).id, exchange);
      expect(requests[0], requests[1]);
      client.close();
      await expectLater(client.read(), throwsStateError);
      expect(requests.length, 2);
    },
  );
  test('late response is discarded after close', () async {
    final pending = Completer<Map<String, dynamic>>();
    final client = repo((_, _) => pending.future);
    final reading = client.read();
    client.close();
    pending.complete({'exchange': state()});
    await expectLater(reading, throwsStateError);
  });
  test('wrong devices, exchange and oversized payload are rejected', () async {
    final response = state()
      ..['toBindingId'] = '44444444-4444-4444-8444-444444444444';
    var calls = 0;
    final client = repo((_, _) async {
      calls++;
      return {'exchange': response};
    });
    await expectLater(client.read(), throwsFormatException);
    await expectLater(
      client.offer(exchange, {'x': 'x' * 8192}),
      throwsArgumentError,
    );
    expect(calls, 1);
    response['toBindingId'] = peer;
    response['exchangeId'] = '55555555-5555-4555-8555-555555555555';
    await expectLater(
      client.offer(exchange, {
        'signed': {'data': 1},
      }),
      throwsFormatException,
    );
  });
  test('recipient answer preserves offer and expiry and checks payload acknowledgement', () async {
    final incoming = state(incoming: true);
    var response = {
      ...incoming,
      'answer': {'response': true},
    };
    final client = repo((_, _) async => {'exchange': response});
    final snapshot = NetworkExchange.parse(incoming);
    final answered = await client.answer(snapshot, {'response': true});
    expect(answered.answer, {'response': true});
    response = {...response, 'expiresAtMs': answered.expiresAtMs + 1};
    await expectLater(
      client.answer(snapshot, {'response': true}),
      throwsFormatException,
    );
    await expectLater(
      client.answer(NetworkExchange.parse(state()), {'response': true}),
      throwsStateError,
    );
  });
  test(
    'cancel must be acknowledged and expired exchange cannot be used',
    () async {
      final response = state();
      final client = repo((_, _) async => {'exchange': response});
      await expectLater(client.cancel(exchange), throwsFormatException);
      response['cancelled'] = true;
      await client.cancel(exchange);
      expect(NetworkExchange.parse(response).requireUsable, throwsStateError);
      response['cancelled'] = false;
      response['expiresAtMs'] = 1;
      expect(NetworkExchange.parse(response).requireUsable, throwsStateError);
    },
  );
}
