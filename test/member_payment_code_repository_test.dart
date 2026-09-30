import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:kingclub/src/features/membership_wallet/data/member_payment_code_repository.dart';

void main() {
  test('session changes during read prevent sending consent', () async {
    var epoch = 0, calls = 0;
    final pending = Completer<Map<String, dynamic>?>();
    final repo = MemberPaymentCodeRepository(
      readSession: () => pending.future,
      generation: () => epoch,
      send: (_, _) async {
        calls++;
        return {'result': {}};
      },
    );
    final request = repo.issue({
      'paymentConsent': true,
    }, stillCurrent: () => true);
    final assertion = expectLater(request, throwsStateError);
    epoch++;
    pending.complete({
      'account': {'userAccount': 'OTHER_TEST_MEMBER'},
    });
    await assertion;
    expect(calls, 0);
  });
  test('page invalidated during read prevents sending consent', () async {
    var current = true, sent = false;
    final pending = Completer<Map<String, dynamic>?>();
    final repo = MemberPaymentCodeRepository(
      readSession: () => pending.future,
      send: (_, _) async {
        sent = true;
        return {'result': {}};
      },
    );
    final assertion = expectLater(
      repo.issue({}, stillCurrent: () => current),
      throwsStateError,
    );
    current = false;
    pending.complete({});
    await assertion;
    expect(sent, isFalse);
  });
  test('valid action sends with captured session and unwraps result', () async {
    final session = <String, dynamic>{'sessionId': 'TEST_SESSION'};
    final repo = MemberPaymentCodeRepository(
      readSession: () async => session,
      send: (params, actual) async {
        expect(identical(actual, session), isTrue);
        expect(params['paymentConsent'], isTrue);
        return {
          'result': {'grantRef': 'TEST_GRANT'},
        };
      },
    );
    expect(
      await repo.issue({'paymentConsent': true}, stillCurrent: () => true),
      {'grantRef': 'TEST_GRANT'},
    );
  });
}
