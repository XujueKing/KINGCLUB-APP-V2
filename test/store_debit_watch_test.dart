import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/membership_wallet/data/store_debit_watch.dart';

import 'member_balance_snapshot_test.dart' show fixture;

void main() {
  testWidgets(
    'only new committed spend triggers once; balance changes and historical receipts do not',
    (tester) async {
      final raw = fixture();
      raw['recentDebits'] = <Map<String, dynamic>>[];
      final events = StreamController<Map<String, dynamic>>.broadcast();
      final received = <StoreDebitNotice>[];
      final watch = StoreDebitWatch(
        active: () => true,
        load: () async => raw,
        events: events.stream,
        onPaid: received.add,
      );
      await tester.pump();
      events.add({'eventType': 'balance.changed'});
      await tester.pump();
      expect(received, isEmpty);
      raw['recentDebits'] = [
        {
          'operationRef': 'old',
          'storeRef': 'test-store',
          'totalCents': '100',
          'paidAt': '2000-01-01T00:00:00Z',
        },
      ];
      events.add({'eventType': 'balance.changed'});
      await tester.pump();
      expect(received, isEmpty);
      raw['recentDebits'] = [
        {
          'operationRef': 'new',
          'storeRef': 'test-store',
          'totalCents': '100',
          'paidAt': DateTime.parse(raw['snapshotAt'] as String)
              .add(const Duration(seconds: 1))
              .toIso8601String(),
        },
      ];
      events.add({'eventType': 'balance.changed'});
      await tester.pump();
      expect(received.single.amount, BigInt.from(100));
      events.add({'eventType': 'balance.changed'});
      await tester.pump();
      expect(received.length, 1);
      watch.dispose();
      await events.close();
    },
  );
}
