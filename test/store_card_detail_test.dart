import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kingclub/src/features/club/presentation/storage_member_cards.dart';
import 'package:kingclub/src/features/profile_settings/data/profile_repository.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_balance_snapshot.dart';

import 'member_balance_snapshot_test.dart' show fixture;

import 'package:kingclub/src/features/profile_settings/presentation/real_personal_qr_page.dart';

import 'dart:io';

class Repo extends ProfileRepository {
  final raw = fixture();
  @override
  Future<Map<String, dynamic>> load() async => {};
  @override
  Future<File?> image(Map? ref) async => null;
  @override
  Future<Map<String, dynamic>> memberQr({bool forceRefresh = false}) async => {
    'code': 'TEST_MEMBER_CODE',
    'ttlSeconds': 600,
  };
  @override
  Future<Map<String, dynamic>> call(
    String id,
    Map<String, dynamic> params,
  ) async => raw;
}

Future<Map<String, dynamic>> issueStoreCode(Map<String, dynamic> params) async {
  expect(params['accountType'], 'store_balance');
  expect(params['storeRef'], 'test-store');
  return {
    ...params,
    'currency': 'CNY',
    'paymentCode': 'KCPAY1:${'A' * 43}',
    'expiresAt': DateTime.now()
        .toUtc()
        .add(const Duration(seconds: 60))
        .toIso8601String(),
  };
}

void main() {
  testWidgets(
    'card opens its store payment code directly without an extra button',
    (tester) async {
      final repo = Repo();
      final events = StreamController<Map<String, dynamic>>.broadcast();
      await tester.pumpWidget(
        MaterialApp(
          home: StoreCardDetail(
            issuePaymentCode: issueStoreCode,
            store: MemberBalanceSnapshot.parse(repo.raw).stores.first,
            repository: repo,
            events: events.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        find.byKey(const ValueKey('store-card-payment-code')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      await events.close();
    },
  );

  testWidgets(
    'card payment QR and confirmed debit return to fresh card balance',
    (tester) async {
      final repo = Repo();
      final events = StreamController<Map<String, dynamic>>.broadcast();
      repo.raw['stores'][0]['originalPrincipalCents'] = '200000';
      repo.raw['stores'][0]['originalGiftCents'] = '20000';
      await tester.pumpWidget(
        MaterialApp(
          home: StoreCardDetail(
            issuePaymentCode: issueStoreCode,
            store: MemberBalanceSnapshot.parse(repo.raw).stores.first,
            repository: repo,
            events: events.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('250.00'), 100);
      expect(find.text('2,000.00'), findsOneWidget);
      expect(find.text('250.00'), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(QrImageView), 250);
      expect(find.byType(QrImageView), findsOneWidget);
      repo.raw['stores'][0]['principalCents'] = '19900';
      repo.raw['stores'][0]['displayTotalCents'] = '24900';
      repo.raw['stores'][0]['lots'][0]['principalCents'] = '19900';
      repo.raw['summary']['storePrincipalCents'] = '19900';
      repo.raw['summary']['displayTotalCents'] = '34900';
      repo.raw['recentDebits'] = [
        {
          'operationRef': 'test-payment',
          'storeRef': 'test-store',
          'totalCents': '100',
          'paidAt': DateTime.parse(repo.raw['snapshotAt'] as String)
              .add(const Duration(seconds: 1))
              .toIso8601String(),
        },
      ];
      events.add({'eventType': 'balance.changed'});
      await tester.pumpAndSettle();
      expect(find.text('Payment successful'), findsOneWidget);
      await tester.tap(find.text('View balance'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('249.00'), 100);
      expect(find.text('249.00'), findsOneWidget);
      expect(find.text('Payment successful'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await events.close();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('member QR debit success returns to the matching store card', (
    tester,
  ) async {
    final repo = Repo();
    final events = StreamController<Map<String, dynamic>>.broadcast();
    await tester.pumpWidget(
      MaterialApp(
        home: RealPersonalQrPage(
          repository: repo,
          balanceLoader: () async => repo.raw,
          events: events.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    repo.raw['recentDebits'] = [
      {
        'operationRef': 'member-qr-debit',
        'storeRef': 'test-store',
        'totalCents': '100',
        'paidAt': DateTime.parse(repo.raw['snapshotAt'] as String)
            .add(const Duration(seconds: 1))
            .toIso8601String(),
      },
    ];
    events.add({'eventType': 'balance.changed'});
    await tester.pumpAndSettle();
    expect(find.text('Payment successful'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(StoreCardDetail), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Test store'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await events.close();
  });
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('member QR is fully visible without scrolling at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.reset);
      final repo = Repo();
      await tester.pumpWidget(
        MaterialApp(
          home: StoreCardDetail(
            issuePaymentCode: issueStoreCode,
            store: MemberBalanceSnapshot.parse(repo.raw).stores.first,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final qr = tester.getRect(find.byType(QrImageView));
      expect(qr.bottom, lessThanOrEqualTo(size.height - 34));
      expect(qr.top, greaterThan(44));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
