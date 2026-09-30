import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/membership_wallet/presentation/member_payment_code_page.dart';

Map<String, dynamic> result(Map<String, dynamic> input) => {
  'grantRef': '11111111-1111-4111-8111-111111111111',
  'paymentCode': 'KCPAY1:${List.filled(43, 'A').join()}',
  'storeRef': input['storeRef'],
  'accountType': input['accountType'],
  'maxTotalCents': input['maxTotalCents'],
  'currency': 'CNY',
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(seconds: 60))
      .toIso8601String(),
};

Future<void> mount(
  WidgetTester tester,
  Future<Map<String, dynamic>> Function(Map<String, dynamic>) issue,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MemberPaymentCodePage(
        storeRef: 'test-store',
        storeName: 'Test store',
        accountType: 'store_balance',
        issue: issue,
      ),
    ),
  );
  await tester.enterText(find.byType(TextField), '12.34');
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
}

void main() {
  testWidgets('explicit consent issues scoped code, never issues on opening', (
    tester,
  ) async {
    var calls = 0;
    Map<String, dynamic>? request;
    await mount(tester, (input) async {
      calls++;
      request = input;
      return result(input);
    });
    expect(calls, 0);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(request, {
      'storeRef': 'test-store',
      'accountType': 'store_balance',
      'maxTotalCents': 1234,
      'paymentConsent': true,
    });
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('wrong account response never displays a code', (tester) async {
    await mount(
      tester,
      (input) async => result(input)..['accountType'] = 'platform_cash',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });
  testWidgets(
    'expired response never displays a code or automatically retries',
    (tester) async {
      var calls = 0;
      await mount(tester, (input) async {
        calls++;
        return result(input)..['expiresAt'] = '2000-01-01T00:00:00.000Z';
      });
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(calls, 1);
    },
  );
  testWidgets('session change discards an in-flight authorization', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    Map<String, dynamic>? request;
    await mount(tester, (input) {
      request = input;
      return pending.future;
    });
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    SecureSessionStore.changes.add(null);
    await tester.pump();
    pending.complete(result(request!));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });
  testWidgets('backgrounding hides code and resume does not reissue', (
    tester,
  ) async {
    var calls = 0;
    await mount(tester, (input) async {
      calls++;
      return result(input);
    });
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
