import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/secure_together_publication.dart';

void main() {
  final session = <String, dynamic>{
    'account': {'userAccount': 'member-test'},
    'sessionId': 's',
    'apiKeyId': 'k',
    'apiKey': 'test-secret',
  };
  TogetherPublicationQuote quote() => TogetherPublicationQuote(
    ref: 'quote',
    depositCents: '100000',
    priceCents: '15000',
    expiresAt: DateTime(2020),
    policyVersion: 'test',
    sessionIdentity: 'member-test\u0000s\u0000k',
  );
  test(
    'unknown publication retries preserve reference even after quote expiry',
    () async {
      final requests = <Map<String, dynamic>>[];
      final repo = SecureTogetherPublication(
        readSession: () async => session,
        request: (id, params, _) async {
          expect(id, 'K261002001982');
          requests.add(params);
          if (requests.length == 1) throw Exception('connection lost');
          return {
            'result': {
              'partyRef': 'party',
              'frozenCents': '100000',
              'replayed': true,
            },
          };
        },
      );
      await expectLater(
        repo.publish(quote(), requestRef: 'stable'),
        throwsException,
      );
      expect(await repo.publish(quote(), requestRef: 'stable'), 'party');
      expect(requests[0], requests[1]);
    },
  );
  test('another login cannot publish an already confirmed quote', () async {
    var calls = 0;
    final repo = SecureTogetherPublication(
      readSession: () async => {...session, 'sessionId': 'changed'},
      request: (_, _, _) async {
        calls++;
        return {};
      },
    );
    await expectLater(
      repo.publish(quote(), requestRef: 'stable'),
      throwsA(anything),
    );
    expect(calls, 0);
  });
  test('mismatched deposit is not shown as successful publication', () async {
    final repo = SecureTogetherPublication(
      readSession: () async => session,
      request: (_, _, _) async => {
        'result': {'partyRef': 'party', 'frozenCents': '1'},
      },
    );
    await expectLater(
      repo.publish(quote(), requestRef: 'stable'),
      throwsA(anything),
    );
  });
}
