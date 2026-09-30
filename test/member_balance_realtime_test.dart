import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/membership_wallet/presentation/member_balance_page.dart';

import 'member_balance_snapshot_test.dart' as data;

void main() {
  testWidgets(
    'balance events coalesce into authenticated reload, never adopt pushed amounts',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MemberBalancePage(
            events: events.stream,
            load: () async {
              calls++;
              return data.fixture();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      for (var i = 0; i < 10; i++) {
        events.add({'eventType': 'balance.changed', 'cashCents': '99999999'});
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 401));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.textContaining('999999'), findsNothing);
      events.add({'eventType': 'storage.changed'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await events.close();
    },
  );
  testWidgets(
    'event during active load schedules one follow-up without overlapping requests',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      final first = Completer<Map<String, dynamic>>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MemberBalancePage(
            events: events.stream,
            load: () {
              calls++;
              return calls == 1 ? first.future : Future.value(data.fixture());
            },
          ),
        ),
      );
      events.add({'eventType': 'connection.ready'});
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
      first.complete(data.fixture());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 401));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await events.close();
    },
  );
}
