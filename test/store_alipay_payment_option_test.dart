import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/commerce/data/store_payment_availability_repository.dart';
import 'package:kingclub/src/features/commerce/presentation/store_alipay_payment_option.dart';

void main() {
  Map<String, dynamic> session() => {
    'sessionId': 'session',
    'apiKeyId': 'key-id',
    'apiKey': 'fixture',
    'account': {'userAccount': 'member'},
  };
  const row = ValueKey('payment-provider-alipay');
  Widget page(
    StorePaymentAvailabilityRepository repository, {
    String storeRef = 'store-a',
  }) => MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          const Text('微信支付'),
          StoreAlipayPaymentOption(
            storeRef: storeRef,
            repository: repository,
            selected: false,
            onTap: () {},
            label: '支付宝',
            unit: 1,
          ),
        ],
      ),
    ),
  );
  for (final response in [false, null, 'true', true]) {
    testWidgets('only explicit store capability shows legacy logo: $response', (
      tester,
    ) async {
      final pending = Completer<Map<String, dynamic>>();
      final repository = StorePaymentAvailabilityRepository(
        readSession: () async => session(),
        request: (id, params, _) {
          expect(id, 'K261002001959');
          expect(params, {'storeRef': 'store-a'});
          return pending.future;
        },
      );
      await tester.pumpWidget(page(repository));
      expect(find.byKey(row), findsNothing);
      pending.complete({
        'result': {'storeRef': 'store-a', 'alipayAvailable': response},
      });
      await tester.pumpAndSettle();
      expect(find.byKey(row), response == true ? findsOneWidget : findsNothing);
      expect(find.text('微信支付'), findsOneWidget);
      if (response == true) {
        final image = tester.widget<Image>(find.byType(Image));
        expect(
          (image.image as AssetImage).assetName,
          'assets/legacy/payment/legacy_alipay.png',
        );
        expect(image.width, 44);
        expect(image.height, 44);
      }
    });
  }
  testWidgets(
    'foreign store, request failure and changed account stay hidden',
    (tester) async {
      for (final kind in ['foreign', 'failure', 'session']) {
        var current = session();
        final repo = StorePaymentAvailabilityRepository(
          readSession: () async => current,
          request: (_, _, _) async {
            if (kind == 'failure') throw StateError('unavailable');
            if (kind == 'session') {
              current = {...session(), 'sessionId': 'different'};
            }
            return {
              'result': {
                'storeRef': kind == 'foreign' ? 'store-b' : 'store-a',
                'alipayAvailable': true,
              },
            };
          },
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(page(repo));
        await tester.pumpAndSettle();
        expect(find.byKey(row), findsNothing);
      }
    },
  );
  testWidgets(
    'store switch discards a late available response; resume rechecks disabled config',
    (tester) async {
      final old = Completer<Map<String, dynamic>>();
      var ready = true;
      final repo = StorePaymentAvailabilityRepository(
        readSession: () async => session(),
        request: (_, p, _) async {
          if (p['storeRef'] == 'store-a') return old.future;
          return {
            'result': {'storeRef': p['storeRef'], 'alipayAvailable': ready},
          };
        },
      );
      await tester.pumpWidget(page(repo));
      await tester.pumpWidget(page(repo, storeRef: 'store-b'));
      await tester.pumpAndSettle();
      expect(find.byKey(row), findsOneWidget);
      old.complete({
        'result': {'storeRef': 'store-a', 'alipayAvailable': false},
      });
      await tester.pumpAndSettle();
      expect(find.byKey(row), findsOneWidget);
      ready = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(row), findsNothing);
    },
  );
  testWidgets('session changes immediately remove an available choice', (
    tester,
  ) async {
    final repo = StorePaymentAvailabilityRepository(
      readSession: () async => session(),
      request: (_, p, _) async => {
        'result': {'storeRef': p['storeRef'], 'alipayAvailable': true},
      },
    );
    await tester.pumpWidget(page(repo));
    await tester.pumpAndSettle();
    expect(find.byKey(row), findsOneWidget);
    SecureSessionStore.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.byKey(row), findsNothing);
  });
}
