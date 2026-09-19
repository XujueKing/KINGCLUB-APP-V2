import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/commerce/data/table_management_repository.dart';
import 'package:kingclub/src/features/commerce/presentation/table_party_page.dart';
import 'package:kingclub/src/features/commerce/presentation/daily_table_settings_page.dart';
import 'package:kingclub/src/features/commerce/presentation/table_ordering_entry_page.dart';
import 'package:kingclub/src/features/commerce/presentation/scan_ordering_cart_page.dart';
import 'package:kingclub/src/features/commerce/data/ordering_catalog_repository.dart';

import 'ordering_catalog_repository_test.dart' show scope, credentials;

Map<String, dynamic> partyPayload() => {
  'result': {
    'tableId': 'table',
    'storeRef': 'store',
    'sessionRef': scope.tableSessionRef,
    'revision': 0,
    'partySize': null,
    'requiredCups': null,
    'canEdit': true,
  },
};
void main() {
  testWidgets(
    'scanned table waits for guest count before presenting the cart',
    (tester) async {
      final repo = TableManagementRepository(
        readSession: () async => credentials(),
        request: (id, params, _) async {
          if (id == 'K260920000818') return partyPayload();
          return {
            'result': {
              ...params,
              'revision': 1,
              'requiredCups': params['partySize'],
            },
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TableOrderingEntryPage(
            tableId: 'table',
            onBack: () {},
            resolveTable: (_) async => scope,
            readCatalog: (_) async => const OrderingCatalog(scope, [], []),
            tableManagement: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TablePartyPage), findsOneWidget);
      expect(find.byType(ScanOrderingCartPage), findsNothing);
      await tester.tap(find.text('确认并点单'));
      await tester.pumpAndSettle();
      expect(find.byType(ScanOrderingCartPage), findsOneWidget);
    },
  );
  test('rejects a different table session and mismatched cups', () async {
    final payload = partyPayload();
    final repo = TableManagementRepository(
      readSession: () async => credentials(),
      request: (_, _, _) async => payload,
    );
    expect((await repo.readParty(scope)).count, isNull);
    (payload['result'] as Map)['sessionRef'] = 'other';
    await expectLater(repo.readParty(scope), throwsA(isA<AuthFailure>()));
    (payload['result'] as Map)['sessionRef'] = scope.tableSessionRef;
    (payload['result'] as Map)['requiredCups'] = 4;
    await expectLater(repo.readParty(scope), throwsA(isA<AuthFailure>()));
  });
  test('detects credentials mutated during request', () async {
    final session = credentials();
    final repo = TableManagementRepository(
      readSession: () async => session,
      request: (_, _, _) async {
        session['apiKey'] = 'changed';
        return partyPayload();
      },
    );
    await expectLater(
      repo.readParty(scope),
      throwsA(
        isA<AuthFailure>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
      ),
    );
  });
  test('malformed history is rejected before the page renders', () async {
    final repo = TableManagementRepository(
      readSession: () async => credentials(),
      request: (_, _, _) async => {
        'result': {
          'tableId': 'table',
          'storeRef': 'store',
          'businessDate': '2026-09-20',
          'entries': [
            {
              'revision': 1,
              'rule': {'mode': 'unknown'},
            },
          ],
          'nextBeforeRevision': null,
        },
      },
    );
    await expectLater(
      repo.history('table', 'store', '2026-09-20'),
      throwsA(isA<AuthFailure>()),
    );
  });
  testWidgets('existing guest count continues without another save', (
    tester,
  ) async {
    var ready = 0, saved = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TablePartyPage(
          tableName: 'T',
          locale: const Locale('zh'),
          read: () async => const TableParty(1, 3, true),
          save: (_, _, _) async {
            saved++;
            return const TableParty(2, 3, true);
          },
          onReady: () => ready++,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(ready, 1);
    expect(saved, 0);
  });
  testWidgets(
    'uncertain save retries the same UUID and does not continue early',
    (tester) async {
      final ids = <String>[];
      var ready = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TablePartyPage(
            tableName: 'T',
            locale: const Locale('zh'),
            read: () async => const TableParty(0, null, true),
            save: (count, revision, id) async {
              ids.add(id);
              if (ids.length == 1) throw Exception('network');
              return TableParty(1, count, true);
            },
            onReady: () => ready++,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4');
      await tester.tap(find.text('确认并点单'));
      await tester.pumpAndSettle();
      expect(ready, 0);
      await tester.tap(find.text('确认并点单'));
      await tester.pumpAndSettle();
      expect(ids[0], ids[1]);
      expect(ready, 1);
    },
  );
  for (final locale in [
    const Locale('zh'),
    const Locale('en'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    const Locale('th'),
  ]) {
    testWidgets('small-screen settings and party forms fit $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = TableManagementRepository(
        readSession: () async => credentials(),
        request: (_, _, _) async => {
          'result': {
            'tableId': 'table',
            'storeRef': 'store',
            'businessDate': '2026-09-20',
            'entries': [],
            'nextBeforeRevision': null,
          },
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: DailyTableSettingsPage(
              tableId: 'table',
              storeRef: 'store',
              businessDate: '2026-09-20',
              repository: repo,
              locale: locale,
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: TablePartyPage(
            tableName: 'T',
            locale: locale,
            read: () async => const TableParty(0, null, true),
            save: (count, _, _) async => TableParty(1, count, true),
            onReady: () {},
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
