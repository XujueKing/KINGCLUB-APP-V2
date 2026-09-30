import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_balance_snapshot.dart';
import 'package:kingclub/src/features/membership_wallet/presentation/member_balance_page.dart';

import 'member_balance_snapshot_test.dart' as data;
import 'support/member_wallet_lifecycle.dart';

Map<String, dynamic> expiring({bool expired = false}) {
  final raw = data.fixture();
  final lot = raw['stores'][0]['lots'][0];
  lot['giftExpiresAt'] = '2026-09-30T00:00:02.000Z';
  if (expired) {
    raw['snapshotAt'] = '2026-09-30T00:00:03.000Z';
    lot['giftExpired'] = true;
    raw['stores'][0]['giftCents'] = '0';
    raw['stores'][0]['expiredGiftCents'] = '6000';
    raw['stores'][0]['displayTotalCents'] = '20000';
    raw['summary']['storeGiftCents'] = '0';
    raw['summary']['displayTotalCents'] = '30000';
  }
  return raw;
}

void main() {
  test('only positive, unexpired gifts schedule a transition', () {
    expect(MemberBalanceSnapshot.parse(data.fixture()).nextGiftExpiry, isNull);
    expect(
      MemberBalanceSnapshot.parse(expiring()).nextGiftExpiry,
      DateTime.utc(2026, 9, 30, 0, 0, 2),
    );
    expect(
      MemberBalanceSnapshot.parse(expiring(expired: true)).nextGiftExpiry,
      isNull,
    );
  });
  testWidgets(
    'expiry clears old total and awaits server rather than locally debiting',
    (tester) async {
      var calls = 0;
      final next = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: MemberBalancePage(
            events: const Stream.empty(),
            load: () => ++calls == 1 ? Future.value(expiring()) : next.future,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CNY 350.00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(calls, 2);
      expect(find.text('CNY 350.00'), findsNothing);
      expect(find.text('CNY 300.00'), findsNothing);
      next.complete(expiring(expired: true));
      await tester.pumpAndSettle();
      expect(find.text('CNY 300.00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('background cancels expiry read until foreground reload', (
    tester,
  ) async {
    await walletLifecycle(tester, AppLifecycleState.resumed);
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MemberBalancePage(
          events: const Stream.empty(),
          load: () async {
            calls++;
            return expiring();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await walletLifecycle(tester, AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 1);
    expect(find.text('CNY 350.00'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await walletLifecycle(tester, AppLifecycleState.resumed);
  });
}
