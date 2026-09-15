import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/call_presentation_lease.dart';

void main() {
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
