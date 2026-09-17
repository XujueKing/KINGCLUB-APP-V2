import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/call_presentation_lease.dart';
import 'package:kingclub/src/features/messaging/presentation/call_presentation_scope.dart';

void main() {
  testWidgets('destroying navigator completes the awaiting presenter', (
    tester,
  ) async {
    final lease = CallPresentationLease.acquire()!;
    var complete = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              await pushCallPresentation(
                Navigator.of(context),
                const Scaffold(body: Text('call')),
                lease,
              );
              complete = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(complete, false);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(complete, true);
    final next = CallPresentationLease.acquire();
    expect(next, isNotNull);
    next?.release();
  });

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
