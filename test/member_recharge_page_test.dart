import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_recharge_flow.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_recharge_journal.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_recharge_repository.dart';
import 'package:kingclub/src/features/membership_wallet/presentation/member_recharge_page.dart';

import 'member_recharge_catalog_test.dart' as catalog;
import 'member_recharge_repository_test.dart' as api;
import 'member_recharge_journal_test.dart' as journal_fixture;
import 'support/member_wallet_lifecycle.dart';

class Fixture {
  String? saved;
  final calls = <String>[];
  bool shortLivedOffer = false;
  Completer<Map<String, dynamic>>? gate;
  late final journal = MemberRechargeJournal(
    read: () async => saved,
    write: (v) async {
      saved = v;
    },
  );
  late final flow = MemberRechargeFlow(
    journal: journal,
    baseUrl: 'https://service.invalid',
    account: () async => 'TEST_MEMBER',
    repository: MemberRechargeRepository(
      call: (id, params) async {
        calls.add(id);
        if (id == 'K260930000512') {
          final result = catalog.fixture();
          if (shortLivedOffer) {
            final now = DateTime.fromMillisecondsSinceEpoch(
              DateTime.now().millisecondsSinceEpoch,
              isUtc: true,
            );
            result['snapshotAt'] = now.toIso8601String();
            for (final offer in result['campaigns'] as List) {
              (offer as Map)['availableUntil'] = now
                  .add(const Duration(seconds: 5))
                  .toIso8601String();
            }
          }
          return result;
        }
        if (id == 'K260930000510') {
          return gate == null ? api.original() : await gate!.future;
        }
        return {'state': 'credit_pending', 'rechargeRef': api.request};
      },
    ),
  );
}

Future<void> mount(WidgetTester tester, Fixture fixture) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MemberRechargePage(storeRef: 'TEST_STORE', flow: fixture.flow),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Select offer'));
  await tester.tap(find.text('Select offer'));
  await tester.pump();
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
  await tester.ensureVisible(find.byType(FilledButton));
}

void main() {
  testWidgets('offer deadline clears selection before catalog TTL', (
    tester,
  ) async {
    final fixture = Fixture()..shortLivedOffer = true;
    await mount(tester, fixture);
    await choose(tester);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(find.byType(FilledButton), findsNothing);
    expect(fixture.calls, ['K260930000512']);
    expect(fixture.saved, isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('requires offer and consent; handoff is only original UUID', (
    tester,
  ) async {
    final fixture = Fixture();
    await mount(tester, fixture);
    expect(fixture.calls, ['K260930000512']);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await choose(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(fixture.calls, ['K260930000512', 'K260930000510']);
    expect(fixture.saved, isNotNull);
    await tester.scrollUntilVisible(
      find.byType(QrImageView),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      api.request,
    );
    expect(find.byType(FilledButton), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('saved original takes precedence over a new offer catalog', (
    tester,
  ) async {
    final fixture = Fixture();
    // Existing disk contents at launch, not an asynchronous pre-frame UI action.
    fixture.saved = jsonEncode([journal_fixture.request().encoded]);
    await mount(tester, fixture);
    expect(fixture.calls, isEmpty);
    expect(find.byType(FilledButton), findsNothing);
    await tester.tap(find.text('Recover and query original'));
    await tester.pumpAndSettle();
    expect(fixture.calls, ['K260930000510', 'K260930000511']);
    expect(find.text('Payment confirmed; credit pending'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(fixture.saved, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'background invalidates late creation and prevents automatic resend',
    (tester) async {
      final fixture = Fixture()..gate = Completer<Map<String, dynamic>>();
      await mount(tester, fixture);
      await choose(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await walletLifecycle(tester, AppLifecycleState.paused);
      await tester.pump();
      fixture.gate!.complete(api.original());
      await tester.pumpAndSettle();
      await walletLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(fixture.calls.where((id) => id == 'K260930000510').length, 1);
      expect(fixture.saved, isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
