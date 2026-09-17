import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/call_presentation_lease.dart';

void main() {
  test(
    'session reset and delayed completion do not strand or release a new flow',
    () {
      final owner = CallPresentationOwner();
      final old = owner.acquire()!;
      expect(CallPresentationLease.acquire(), isNull);
      owner.reset();
      final current = owner.acquire()!;
      owner.release(old);
      expect(owner.acquire(), isNull);
      expect(CallPresentationLease.acquire(), isNull);
      owner.release(current);
      final next = owner.acquire();
      expect(next, isNotNull);
      owner.reset();
    },
  );

  test('call flow excludes every other presenter until released', () {
    final outgoing = CallPresentationLease.acquire()!;
    expect(CallPresentationLease.acquire(), isNull);
    outgoing.release();
    final incoming = CallPresentationLease.acquire()!;
    outgoing.release(); // A late old finally cannot unlock the new route.
    expect(CallPresentationLease.acquire(), isNull);
    incoming.release();
    final next = CallPresentationLease.acquire();
    expect(next, isNotNull);
    next!.release();
  });
}
