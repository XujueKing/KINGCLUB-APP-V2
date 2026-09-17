import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/call_presentation_lease.dart';
import 'package:kingclub/src/features/messaging/presentation/call_presentation_scope.dart';

void main() {
  testWidgets(
    'route disposal releases ownership and late completion preserves the next call',
    (tester) async {
      final original = CallPresentationLease.acquire()!;
      await tester.pumpWidget(
        CallPresentationScope(lease: original, child: const SizedBox()),
      );
      expect(CallPresentationLease.acquire(), isNull);
      await tester.pump();
      expect(CallPresentationLease.acquire(), isNull);
      await tester.pumpWidget(const SizedBox());
      final next = CallPresentationLease.acquire();
      expect(next, isNotNull);
      original.release();
      expect(CallPresentationLease.acquire(), isNull);
      next!.release();
    },
  );
}
