import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';
import 'package:kingclub/src/features/commerce/presentation/table_ordering_entry_page.dart';

import 'package:kingclub/src/features/membership_wallet/presentation/member_payment_code_page.dart';

import 'live_ordering_catalog_flow_test.dart' as catalog_fixture;
import 'ordering_catalog_repository_test.dart' as fixture;

void main() {
  testWidgets(
    'live store offers distinct accounts without requiring a recharge account',
    (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ScanOrderingCartPage(
            onBack: () {},
            orderingContext: fixture.scope,
            catalog: catalog_fixture.catalog(),
            onOpenBalancePayment: selected.add,
          ),
        ),
      );
      expect(selected, isEmpty);
      final entry = find.byKey(const ValueKey('ordering-balance-payment'));
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      await tester.tap(find.text('用平台现金付款'));
      await tester.pumpAndSettle();
      expect(selected, ['platform_cash']);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await tester.tap(find.text('用本店余额付款'));
      await tester.pumpAndSettle();
      expect(selected, ['platform_cash', 'store_balance']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'preview does not expose payment even with an injected callback',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ScanOrderingCartPage(
            onBack: () {},
            onOpenBalancePayment: (_) => calls++,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('ordering-balance-payment')),
        findsNothing,
      );
      expect(calls, 0);
    },
  );
  testWidgets(
    'resolved entry binds payment callback only when feature is enabled',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TableOrderingEntryPage(
            tableId: 'TEST_TABLE',
            onBack: () {},
            resolveTable: (_) async => fixture.scope,
            readCatalog: (_) async => catalog_fixture.catalog(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cart = tester.widget<ScanOrderingCartPage>(
        find.byType(ScanOrderingCartPage),
      );
      expect(
        cart.onOpenBalancePayment != null,
        const bool.fromEnvironment('KINGCLUB_MEMBER_PAYMENT'),
      );
      if (const bool.fromEnvironment('KINGCLUB_MEMBER_PAYMENT')) {
        cart.onOpenBalancePayment!('platform_cash');
        await tester.pumpAndSettle();
        final payment = tester.widget<MemberPaymentCodePage>(
          find.byType(MemberPaymentCodePage),
        );
        expect(payment.storeRef, fixture.scope.storeRef);
        expect(payment.storeName, fixture.scope.storeName);
        expect(payment.accountType, 'platform_cash');
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
